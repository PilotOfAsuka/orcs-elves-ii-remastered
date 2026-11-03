#!/usr/bin/env python3
"""JVM class parser adapted from the local WolfMoon project. Game resource formats are separate."""
from __future__ import annotations
import argparse, collections, hashlib, io, json, pathlib, struct, subprocess, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

class Reader:
    def __init__(self, data: bytes): self.data, self.p = data, 0
    def take(self, n):
        if n < 0 or self.p+n > len(self.data): raise ValueError(f"Truncated at {self.p}, need {n}")
        b = self.data[self.p:self.p+n]; self.p += n; return b
    def num(self, f): return struct.unpack('>'+f, self.take(struct.calcsize('>'+f)))[0]
    def utf(self):
        # DataInput modified UTF-8: encode UTF-16 code units; NUL uses C0 80.
        b = self.take(self.num('H')); units=[]; p=0
        while p < len(b):
            c=b[p]; p+=1
            if c < 128: units.append(c)
            elif c & 224 == 192:
                units.append(((c&31)<<6)|(b[p]&63)); p+=1
            elif c & 240 == 224:
                units.append(((c&15)<<12)|((b[p]&63)<<6)|(b[p+1]&63)); p+=2
            else: raise ValueError('Invalid modified UTF-8')
        return b''.join(struct.pack('>H',u) for u in units).decode('utf-16-be')

def signature(desc):
    args=[]; p=1
    while desc[p] != ')':
        s=p
        while desc[p]=='[': p+=1
        if desc[p]=='L': p=desc.index(';',p)+1
        else: p+=1
        args.append(desc[s:p])
    return args,desc[p+1:]

def parse_class(data):
    r=Reader(data)
    assert r.num('I')==0xcafebabe
    minor,major=r.num('H'),r.num('H'); count=r.num('H'); cp=[None]*count; j=1
    while j<count:
        tag=r.num('B')
        if tag==1: v=r.utf()
        elif tag in (3,4): v=r.num('i' if tag==3 else 'f')
        elif tag in (5,6): v=r.num('q' if tag==5 else 'd')
        elif tag in (7,8,16): v=r.num('H')
        elif tag in (9,10,11,12,18): v=[r.num('H'),r.num('H')]
        elif tag==15: v=[r.num('B'),r.num('H')]
        else: raise ValueError(f'CP tag {tag}')
        cp[j]=(tag,v); j += 2 if tag in (5,6) else 1
    def val(n):
        if not n: return None
        t,v=cp[n]
        if t in (7,8): return val(v)
        if t in (9,10,11):
            name,desc=val(v[1]); res=dict(owner=val(v[0]),name=name,desc=desc)
            if t!=9: res['params'],res['return']=signature(desc)
            return res
        if t==12: return [val(v[0]),val(v[1])]
        if t==5: return dict(kind='long',v=v)
        return v
    flags=r.num('H'); name=val(r.num('H')); parent=val(r.num('H'))
    interfaces=[val(r.num('H')) for _ in range(r.num('H'))]
    def attrs(q):
        res={}
        for _ in range(q.num('H')):
            key=val(q.num('H')); res[key]=q.take(q.num('I'))
        return res
    fields=[]
    for _ in range(r.num('H')):
        f=dict(flags=r.num('H'),name=val(r.num('H')),desc=val(r.num('H'))); a=attrs(r)
        if 'ConstantValue' in a: f['constant']=val(Reader(a['ConstantValue']).num('H'))
        fields.append(f)
    methods={}; opcounts=collections.Counter()
    for _ in range(r.num('H')):
        m=dict(flags=r.num('H'),name=val(r.num('H')),desc=val(r.num('H'))); a=attrs(r)
        m['params'],m['return']=signature(m['desc'])
        if 'Code' in a:
            q=Reader(a['Code']); m['max_stack']=q.num('H'); m['max_locals']=q.num('H'); code=q.take(q.num('I'))
            instructions=[]; offsets={}; s=Reader(code)
            while s.p<len(code):
                pc=s.p; op=s.num('B'); opcounts[op]+=1; operands=[]
                if op==16: operands=[s.num('b')]
                elif op==17: operands=[s.num('h')]
                elif op in (18,19,20): operands=[val(s.num('B' if op==18 else 'H'))]
                elif op in (21,22,23,24,25,54,55,56,57,58,169,188): operands=[s.num('B')]
                elif op==132: operands=[s.num('B'),s.num('b')]
                elif 153<=op<=168 or op in (198,199): operands=[pc+s.num('h')]
                elif op in (200,201): operands=[pc+s.num('i')]
                elif op in (170,171):
                    s.take((-s.p)%4); default=pc+s.num('i'); pairs=[]
                    if op==170:
                        low,high=s.num('i'),s.num('i')
                        pairs=[[k,pc+s.num('i')] for k in range(low,high+1)]
                    else: pairs=[[s.num('i'),pc+s.num('i')] for _ in range(s.num('i'))]
                    operands=[default,pairs]
                elif 178<=op<=185:
                    operands=[val(s.num('H'))]
                    if op==185: s.take(2)
                elif op in (187,189,192,193): operands=[val(s.num('H'))]
                elif op==197: operands=[val(s.num('H')),s.num('B')]
                elif op==196:
                    sub=s.num('B'); operands=[sub,s.num('H')]
                    if sub==132: operands.append(s.num('h'))
                elif op==186: raise ValueError('Unexpected invokedynamic')
                offsets[pc]=len(instructions); instructions.append([op,*operands])
            offsets[len(code)]=len(instructions)
            for ins in instructions:
                op=ins[0]
                if 153<=op<=168 or op in (198,199,200,201): ins[1]=offsets[ins[1]]
                elif op in (170,171):
                    ins[1]=offsets[ins[1]]
                    for pair in ins[2]: pair[1]=offsets[pair[1]]
            m['code']=instructions; m['offsets']=[p for p in offsets if p<len(code)]; m['exceptions']=[]
            for _ in range(q.num('H')):
                start,end,handler,t=[q.num('H') for _ in range(4)]
                m['exceptions'].append(dict(start=offsets[start],end=offsets[end],handler=offsets[handler],type=val(t)))
            attrs(q); assert q.p==len(q.data)
        methods[m['name']+m['desc']]=m
    attrs(r); assert r.p==len(data)
    deps=sorted(set(val(j) for j in range(1,count) if cp[j] and cp[j][0]==7))
    refs=[val(j) for j in range(1,count) if cp[j] and cp[j][0] in (9,10,11)]
    constants=[dict(index=n,tag=cp[n][0],value=val(n)) for n in range(1,count) if cp[n] and cp[n][0] in (1,3,4,5,6,7,8)]
    return dict(name=name,parent=parent,interfaces=interfaces,flags=flags,version=[major,minor],fields=fields,methods=methods,dependencies=deps,references=refs,constants=constants),opcounts

def dump(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')

