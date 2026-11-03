class_name OEFontHelpers
extends RefCounted
## Exact equivalents of the original b font lookup, measurement and paint paths.
## Full bytecode remains available as the oracle; tests/font_parity.gd compares it.
var vm: OEVM

func _init(machine: OEVM) -> void:
	vm=machine

func accepts(owner: String, key: String, args: Array=[]) -> bool:
	if owner!="b": return false
	if key=="a(III)I": return true
	if key=="a(SI)S": return args.size()==2 and int(args[1])==0
	if int(vm.get_static("a","a","B"))!=4: return false
	if key=="a(S)S": return true
	if key=="a(Ljava/lang/StringBuffer;)I": return args.size()==1 and args[0] is JObject and args[0].data is String and not args[0].data.ends_with(String.chr(31))
	if key=="a(Ljava/lang/StringBuffer;IIIII)V" and args.size()==6 and args[0] is JObject and args[0].data is String:
		var text: String=args[0].data
		# $-prefixed icon labels mutate their source buffer and call the game's
		# icon routine; keep that complete path in the interpreter for now.
		return not text.ends_with(String.chr(31)) and not (text.length()>3 and text.begins_with("$")) and int(args[4])>=0 and int(args[5])>=-1
	return false

func invoke(key: String, args: Array) -> int:
	if key=="a(Ljava/lang/StringBuffer;IIIII)V": paint(args);return 0
	if key=="a(SI)S": return glyph(int(args[0]),int(args[1]))
	if key=="a(Ljava/lang/StringBuffer;)I": return measure(args[0])
	if key=="a(S)S":
		var value: int=int(args[0])
		var source_array: Variant=vm.get_static("b","a","[S")
		var target_array: Variant=vm.get_static("b","b","[S")
		if not source_array is JObject or not target_array is JObject:
			vm.throw_exception("java/lang/NullPointerException");return 0
		var source: Array=source_array.data
		var target: Array=target_array.data
		for index in mini(source.size(),maxi(0,value)):
			if value==int(source[index]):
				var slot: int=index if int(vm.get_static("a","a","B"))==4 or index>target.size()-source.size() else source.size()+index
				if slot<0 or slot>=target.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(slot));return 0
				return int(target[slot])
		return value
	return search(int(args[0]),int(args[1]),int(args[2]))

func glyph(value: int, page: int=0) -> int:
	var index: int
	if page==0: index=search(value,0,int(vm.get_static("b","b","I"))-2)
	else: index=int(vm.get_static("b","a","[[S").data[page].data[value])&65535
	return int(vm.get_static("b","c","[S").data[index])

func measure(buffer: JObject) -> int:
	var text: String=buffer.data
	if text.is_empty(): return 0
	var bytes: Array=vm.get_static("b","c","[B").data
	var width: int=0
	var index: int=0
	while index<text.length():
		var escaped: bool=false
		var code: int=invoke("a(S)S",[OEVM.signed(text.unicode_at(index),16)])
		if code==31:
			index+=1
			if index>=text.length(): vm.throw_exception("java/lang/StringIndexOutOfBoundsException");return 0
			code=OEVM.signed(1040+text.unicode_at(index)-60,16);escaped=true
		if not escaped and ((code==173 and index!=text.length()-1) or code==10 or (code>=176 and code<187)):
			index+=1;continue
		var pointer: int=glyph(code)
		if pointer==-1: width=OEVM.i32(width+15)
		else:
			var cursor: int=OEVM.signed(pointer+2,16)
			var count: int=int(bytes[OEVM.signed(pointer+1,16)])&255
			var left: int=99999
			var right: int=-1
			for segment in count:
				var offset: int=int(bytes[OEVM.signed(cursor+2,16)])
				var extent: int=int(bytes[OEVM.signed(cursor+4,16)])&255
				left=mini(left,offset);right=maxi(right,offset+extent)
				cursor=OEVM.signed(cursor+6,16)
			width=OEVM.i32(width+right-left)
		index+=1
	return width

func paint(args: Array) -> void:
	var buffer: JObject=args[0]
	var text: String=buffer.data
	if text.is_empty(): return
	var x: int=args[1]
	var y: int=OEVM.i32(int(args[2])-4)
	var anchor: int=args[3]
	var start: int=args[4]
	var limit: int=666 if int(args[5])==-1 else int(args[5])
	var inset: int=vm.get_static("a","Z","I")
	if inset!=0:
		x=OEVM.i32(x+OEVM.i32(int(vm.get_static("a","Y","I"))-inset)/2)
		y=OEVM.i32(y+OEVM.i32(int(vm.get_static("a","X","I"))-inset-20)/2)
	var header: Array=vm.get_static("b","b","[B").data
	var baseline: int=int(header[2])&255
	var font_height: int=OEVM.i32((int(header[2])&255)+(int(header[3])&255)+int(header[1]))
	if (anchor&8)!=0: x=OEVM.i32(x-measure(buffer))
	elif (anchor&16)!=0: x=OEVM.i32(x-(measure(buffer)>>1))
	if (anchor&2)!=0: y=OEVM.i32(y-27)
	elif (anchor&32)!=0: y=OEVM.i32(y-13)
	var row_start: int=x
	if vm.get_static("b","a","[[S").data[0]==null: return
	var end: int=maxi(start,mini(OEVM.i32(start+limit),text.length()))
	var bytes: Array=vm.get_static("b","c","[B").data
	var graphics: OEMidpGraphics=vm.get_static("a","a","Ljavax/microedition/lcdui/Graphics;").data
	var image: JObject=vm.get_static("b","a","Ljavax/microedition/lcdui/Image;")
	var index: int=start
	while index<end:
		var escaped: bool=false
		var code: int=invoke("a(S)S",[OEVM.signed(text.unicode_at(index),16)])
		if code==31:
			index+=1
			if index>=text.length(): vm.throw_exception("java/lang/StringIndexOutOfBoundsException");return
			code=OEVM.signed(1040+text.unicode_at(index)-60,16);escaped=true
		if code==173 and index!=end-1 and not escaped: index+=1;continue
		if code==10 and not escaped:
			y=OEVM.i32(y+27);x=row_start;index+=1;continue
		var pointer: int=glyph(code)
		if pointer==-1:
			if code!=32:
				var previous: int=graphics.color.to_rgba32()>>8
				graphics.set_color(0x00ff00);graphics.fill_rect(x,y,15,font_height)
				graphics.set_color(0xff0000);graphics.line(x,y,OEVM.i32(x+15),OEVM.i32(y+font_height))
				graphics.line(x,OEVM.i32(y+font_height),OEVM.i32(x+15),y);graphics.set_color(previous)
			x=OEVM.i32(x+15);index+=1;continue
		var cursor: int=OEVM.signed(pointer+2,16)
		var count: int=int(bytes[OEVM.signed(pointer+1,16)])&255
		var left: int=99999
		var right: int=-1
		for segment in count:
			var u: int=int(bytes[cursor])&255
			var v: int=int(bytes[OEVM.signed(cursor+1,16)])&255
			var dx: int=int(bytes[OEVM.signed(cursor+2,16)])
			var dy: int=int(bytes[OEVM.signed(cursor+3,16)])
			var w: int=int(bytes[OEVM.signed(cursor+4,16)])&255
			var h: int=int(bytes[OEVM.signed(cursor+5,16)])&255
			cursor=OEVM.signed(cursor+6,16)
			left=mini(left,dx);right=maxi(right,dx+w)
			vm.native.draw_region(graphics,[image,u,v,w,h,0,OEVM.i32(x+dx),OEVM.i32(y-dy+baseline-h),0])
		x=OEVM.i32(x+right-left);index+=1

func search(value: int, low: int, high: int) -> int:
	var table: Variant=vm.get_static("b","a","[[S")
	if not table is JObject or table.data.is_empty() or not table.data[0] is JObject:
		vm.throw_exception("java/lang/NullPointerException");return 0
	var codes: Array=table.data[0].data
	while low<=high:
		var middle: int=(low+high)>>1
		if middle<0 or middle>=codes.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(middle));return 0
		var code: int=int(codes[middle])&65535
		if value==code: return middle
		if value<code: high=middle-1
		else: low=middle+1
	return int(vm.get_static("b","b","I"))-1
