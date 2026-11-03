"""Publish this project's source and already-verified Web export to GitHub Pages.

Uses the existing Git credential helper; never writes or prints credentials.
Run only when publication has been explicitly requested.
"""
import argparse,json,os,subprocess,urllib.request,urllib.error
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OWNER='PilotOfAsuka'
NAME='orcs-elves-ii-remastered'
URL=f'https://github.com/{OWNER}/{NAME}.git'

def git(*args,cwd=ROOT):
    return subprocess.check_output(['git',*args],cwd=cwd,text=True,env=dict(os.environ,GIT_TERMINAL_PROMPT='0')).strip()

def api(method,path,body=None):
    credential=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',text=True,capture_output=True,check=True,env=dict(os.environ,GIT_TERMINAL_PROMPT='0'))
    values=dict(row.split('=',1) for row in credential.stdout.splitlines() if '=' in row)
    request=urllib.request.Request('https://api.github.com'+path,method=method,data=None if body is None else json.dumps(body).encode(),headers={'Accept':'application/vnd.github+json','Authorization':'Bearer '+values['password'],'X-GitHub-Api-Version':'2022-11-28','User-Agent':'OrcsElves2-Local-Publisher','Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(request,timeout=40) as response:
            data=response.read();return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        data=error.read().decode();raise RuntimeError(f'GitHub {error.code}: {data}') from None

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['publish','status']);args=parser.parse_args()
    if api('GET','/user')['login'].lower()!=OWNER.lower(): raise RuntimeError('Unexpected GitHub account')
    if args.action=='status':
        p=api('GET',f'/repos/{OWNER}/{NAME}/pages');print(json.dumps({k:p.get(k) for k in ['html_url','status','source','build_type']}));return
    if git('status','--porcelain'): raise RuntimeError('Commit the reviewed source before publishing')
    export=ROOT/'build/web'
    if not all((export/name).is_file() for name in ['index.html','index.js','index.wasm','index.pck']): raise RuntimeError('Web export is missing')
    for path in export.iterdir():
        if path.is_file() and path.stat().st_size>=100_000_000: raise RuntimeError('Export file exceeds GitHub file limit')
    try: repo=api('GET',f'/repos/{OWNER}/{NAME}')
    except RuntimeError as error:
        if not str(error).startswith('GitHub 404:'): raise
        repo=api('POST','/user/repos',{'name':NAME,'description':'Orcs & Elves II in the browser — Classic and Remastered, adaptive controls, Russian / English. Godot 4.7.2.','private':False,'auto_init':False,'has_issues':True})
    if repo['owner']['login'].lower()!=OWNER.lower() or repo.get('archived'): raise RuntimeError('Unexpected repository owner or archived repository')
    remotes=git('remote').splitlines()
    if 'origin' not in remotes: git('remote','add','origin',URL)
    elif git('remote','get-url','origin')!=URL: raise RuntimeError('Unexpected origin; not changing it')
    git('push','origin','HEAD:refs/heads/godot')
    api('PATCH',f'/repos/{OWNER}/{NAME}',{'default_branch':'godot','homepage':f'https://{OWNER.lower()}.github.io/{NAME}/'})
    work=ROOT/'build/pages-publish'
    if not work.exists():
        work.mkdir(parents=True);git('init','-b','web-build',cwd=work)
        git('config','user.name',git('config','user.name'),cwd=work);git('config','user.email',git('config','user.email'),cwd=work)
        git('remote','add','origin',URL,cwd=work)
    import shutil
    for path in export.iterdir():
        if path.is_file(): shutil.copy2(path,work/path.name)
    (work/'.nojekyll').touch();git('add','--all',cwd=work)
    if git('status','--porcelain',cwd=work): git('commit','-m','Publish verified Orcs & Elves II Web build',cwd=work)
    git('push','origin','web-build',cwd=work)
    body={'source':{'branch':'web-build','path':'/'},'build_type':'legacy'}
    try: api('GET',f'/repos/{OWNER}/{NAME}/pages')
    except RuntimeError as error:
        if not str(error).startswith('GitHub 404:'): raise
        api('POST',f'/repos/{OWNER}/{NAME}/pages',body)
    else: api('PUT',f'/repos/{OWNER}/{NAME}/pages',body)
    print(json.dumps({'repository':repo['html_url'],'play':f'https://{OWNER.lower()}.github.io/{NAME}/','source_commit':git('rev-parse','HEAD'),'build_commit':git('rev-parse','HEAD',cwd=work)}))
if __name__=='__main__': main()
