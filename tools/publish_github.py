#!/usr/bin/env python3
"""Publish the reviewed BREW source and browser preview to the existing project.

Only run publish after a user request. Credentials remain inside the existing
Git credential helper and API request headers; they are never logged or saved.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request
import urllib.error

ROOT=Path(__file__).resolve().parents[1]
OWNER='PilotOfAsuka'
NAME='orcs-elves-ii-remastered'
URL=f'https://github.com/{OWNER}/{NAME}.git'
SOURCE_BRANCH='codex/brew-port'
PLAY=f'https://{OWNER.lower()}.github.io/{NAME}/brew/'
FILES=('index.html','index.js','index.wasm','index.pck','index.png',
       'index.audio.position.worklet.js','index.audio.worklet.js',
       'brew-core.js','brew-core.wasm','brew-core.data','runtime.js')
ENV=dict(os.environ,GIT_TERMINAL_PROMPT='0')

def git(*args,cwd=ROOT):
    return subprocess.check_output(['git',*args],cwd=cwd,text=True,env=ENV).strip()

def api(method,path,body=None):
    credential=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',
        text=True,capture_output=True,check=True,env=ENV)
    values=dict(row.split('=',1) for row in credential.stdout.splitlines() if '=' in row)
    token=values.get('password')
    if not token: raise RuntimeError('GitHub credential helper did not supply authentication')
    request=urllib.request.Request('https://api.github.com'+path,method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={'Accept':'application/vnd.github+json','Authorization':'Bearer '+token,
                 'X-GitHub-Api-Version':'2022-11-28','User-Agent':'OrcsElves2-BREW-Publisher',
                 'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(request,timeout=40) as response:
            data=response.read();return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        # Only GitHub's response body is reported; authorization headers stay private.
        raise RuntimeError(f'GitHub {error.code}: {error.read().decode()}') from None

def status():
    pages=api('GET',f'/repos/{OWNER}/{NAME}/pages')
    build=api('GET',f'/repos/{OWNER}/{NAME}/pages/builds/latest')
    print(json.dumps({'play':PLAY,'pages':{k:pages.get(k) for k in ('html_url','status','source','build_type')},
                      'build':{k:build.get(k) for k in ('status','commit','error','updated_at')}}))

def publish():
    if api('GET','/user')['login'].lower()!=OWNER.lower(): raise RuntimeError('Unexpected GitHub account')
    repo=api('GET',f'/repos/{OWNER}/{NAME}')
    if repo['owner']['login'].lower()!=OWNER.lower() or repo.get('archived'): raise RuntimeError('Unexpected target repository')
    if git('status','--porcelain'): raise RuntimeError('Commit reviewed source changes before publishing')
    for name in FILES:
        path=ROOT/'build/web'/name
        if not path.is_file() or path.stat().st_size>=100_000_000: raise RuntimeError(f'Missing or oversized build file: {name}')
    if (ROOT/'build/web/runtime.js').read_bytes()!=(ROOT/'web/runtime.js').read_bytes():
        raise RuntimeError('Browser runtime changed after the Web export')
    if 'origin' not in git('remote').splitlines(): git('remote','add','origin',URL)
    elif git('remote','get-url','origin')!=URL: raise RuntimeError('Unexpected origin')
    # A new source branch preserves existing history and never force-pushes.
    git('push','origin',f'HEAD:refs/heads/{SOURCE_BRANCH}')
    work=ROOT/'build/pages-publish'
    if not work.exists():
        subprocess.run(['git','clone','--single-branch','--branch','web-build',URL,str(work)],check=True,env=ENV)
    else:
        if git('status','--porcelain',cwd=work): raise RuntimeError('Deployment checkout has local changes')
        if git('remote','get-url','origin',cwd=work)!=URL: raise RuntimeError('Unexpected deployment origin')
        git('pull','--ff-only','origin','web-build',cwd=work)
    git('config','user.name',git('config','user.name'),cwd=work)
    git('config','user.email',git('config','user.email'),cwd=work)
    # The preview is self-contained. Other published paths are preserved.
    preview=work/'brew'
    if preview.exists(): shutil.rmtree(preview)
    preview.mkdir()
    manifest={'engine':'BREW','game_version':'7.0.41','source_branch':SOURCE_BRANCH,
              'source_revision':git('rev-parse','HEAD'),'files':{}}
    for name in FILES:
        shutil.copy2(ROOT/'build/web'/name,preview/name)
        data=(preview/name).read_bytes()
        manifest['files'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    shutil.copy2(ROOT/'LICENSE',preview/'LICENSE.txt')
    shutil.copy2(ROOT/'SOURCES.md',preview/'SOURCES.md')
    (preview/'build.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (work/'.nojekyll').touch()
    git('add','--','brew','.nojekyll',cwd=work)
    if git('status','--porcelain',cwd=work): git('commit','-m','Publish BREW 7.0.41 browser preview',cwd=work)
    git('push','origin','web-build',cwd=work)
    api('PATCH',f'/repos/{OWNER}/{NAME}',{'default_branch':SOURCE_BRANCH,'homepage':PLAY,
        'description':'Orcs & Elves II in your browser — BREW Classic, custom adaptive UI, Remastered graphics in development.'})
    pages=api('GET',f'/repos/{OWNER}/{NAME}/pages')
    if pages.get('source')!={'branch':'web-build','path':'/'} or pages.get('build_type')!='legacy':
        raise RuntimeError('Unexpected Pages configuration; inspect before changing it')
    result={'repository':repo['html_url'],'play':PLAY,'source_branch':SOURCE_BRANCH,
            'source_commit':git('rev-parse','HEAD'),'build_commit':git('rev-parse','HEAD',cwd=work)}
    (ROOT/'build/publication.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['publish','status']);args=parser.parse_args()
    status() if args.action=='status' else publish()
