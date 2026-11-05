/* Browser host for the BREW C engine. Godot owns presentation and input;
 * this module owns the fixed-step simulation, persistent files and audio. */
(() => {
  'use strict';
  const script = typeof document !== 'undefined' ? new URL(document.currentScript.src) : null;
  const base = script ? new URL('.', script).href : '';
  const version = script ? script.search : '';
  const SAVE_DIR='/oe2-brew-v1'; // Permanent namespace: never add a build/release tag.
  const SAVE_NAME=/^(Config|SD_[0-9])$/;
  let core, pendingMs = 0, syncTimer, syncChain = Promise.resolve(true);
  const audio = globalThis.BrewAudio = {
    context: null, sources: new Map(), buffers: new Map(), gains: new Map(),
    unlock() {
      const Audio = globalThis.AudioContext || globalThis.webkitAudioContext;
      if (!Audio) return;
      if (!this.context) this.context = new Audio();
      if (this.context.state === 'suspended') this.context.resume();
    },
    play(channel, pointer, samples, rate, loops) {
      this.stop(channel);
      if (!this.context) return;
      const key = `${pointer}:${samples}`;
      let buffer = this.buffers.get(key);
      if (!buffer) {
        buffer = this.context.createBuffer(1, samples, rate);
        const output = buffer.getChannelData(0);
        const input = core.HEAP16.subarray(pointer >> 1, (pointer >> 1) + samples);
        for (let i = 0; i < samples; i++) output[i] = input[i] / 32768;
        this.buffers.set(key, buffer);
      }
      const source = this.context.createBufferSource(), gain = this.context.createGain();
      source.buffer = buffer; source.loop = loops < 0;
      gain.gain.value = this.gains.get(channel) ?? 1;
      source.connect(gain); gain.connect(this.context.destination);
      this.sources.set(channel, { source, gain });
      source.onended = () => { if (this.sources.get(channel)?.source === source) this.sources.delete(channel); };
      source.start();
    },
    stop(channel) { const old = this.sources.get(channel); if (old) { old.source.stop(); this.sources.delete(channel); } },
    playing(channel) { return this.sources.has(channel); },
    volume(channel, value) { const gain = Math.max(0, Math.min(1, value / 100)); this.gains.set(channel, gain); if (this.sources.has(channel)) this.sources.get(channel).gain.gain.value = gain; },
    pause(value) { if (!this.context) return; if (value) this.context.suspend(); else this.context.resume(); }
  };
  const Brew = globalThis.Brew = {
    backupStatus:'', importing:false, qualityLevel: 0, ready: false, error: '', saveError: '', paused: false, tickMs: 0, maxTickMs: 0,
    async init({ persist = typeof document !== 'undefined', seed } = {}) {
      if (this.ready) return this;
      core = await globalThis.createBrewModule({ locateFile: file => base + file + version });
      core.FS.mkdir(SAVE_DIR);
      this.persist = persist;
      if (persist) {
        core.FS.mount(core.IDBFS, {}, SAVE_DIR);
        await new Promise((resolve, reject) => core.FS.syncfs(true, err => err ? reject(err) : resolve()));
      }
      if (seed !== undefined) core._oe2_test_seed(seed);
      const result = core.ccall('oe2_boot', 'number', ['string', 'number', 'number'], ['/gamedata', 176, 220]);
      if (result !== 0) throw new Error(`BREW startup failed (${result})`);
      this.qualityLevel=this.savedQuality();core._oe2_quality(this.qualityLevel);
      this.ready = true;
      return this;
    },
    advance(ms) {
      if (!this.ready || this.paused || this.importing || (typeof document !== 'undefined' && document.hidden)) { pendingMs = 0; return; }
      pendingMs += Math.min(Math.max(ms, 0), 200);
      while (pendingMs >= 40) {
        const start = performance.now(); core._oe2_tick();
        this.tickMs = performance.now() - start; this.maxTickMs = Math.max(this.maxTickMs, this.tickMs);
        pendingMs -= 40;
      }
      if (typeof location !== 'undefined' && location.search.includes('perf=1')) {
        const state = JSON.parse(this.json());
        if (state.ticks % 100 === 0 && state.ticks !== this.lastLogTick) {
          this.lastLogTick = state.ticks;
          console.info('BREW performance', JSON.stringify({ticks:state.ticks,state:state.state,tickMs:this.tickMs,maxTickMs:this.maxTickMs,lightMs:this.lightMs||0,world:`${state.world_width}x${state.world_height}`}));
        }
      }
    },
    json() { return this.ready ? core.UTF8ToString(core._oe2_json()) : '{}'; },
    key(avk) { if (this.ready&&!this.importing) { audio.unlock(); core._oe2_key(avk); } },
    action(action) { if (this.ready) this.key(core._oe2_action_key(action)); },
    menu(id, index) { if (this.ready&&!this.importing) { audio.unlock(); return core._oe2_menu_select(id, index); } return 0; },
    continueText() {
      if(this.ready&&!this.importing){audio.unlock();core._oe2_continue_dialogue();}
    },
    choice(index) {
      if (this.ready&&!this.importing) {
        audio.unlock();core._oe2_choice(index);
      }
    },
    save() { return this.ready&&!this.importing ? core._oe2_save() : 0; },
    load() { return this.ready&&!this.importing ? core._oe2_load() : 0; },
    inventory() { if (this.ready&&!this.importing) core._oe2_inventory(); },
    image(kind) {
      let pointer, length;
      if (kind === 'story_base') { pointer=core._oe2_story_base();length=176*176*4; }
      else if(kind==='travel'){pointer=core._oe2_travel();length=176*203*4;}
      else if (kind === 'story') { pointer = core._oe2_story(); length = 176 * 176 * 4; }
      else if (kind === 'world' || kind === 'lit' || kind === 'classic') {
        const start=performance.now();
        pointer=kind==='lit'?core._oe2_lit_world():(kind==='classic'?core._oe2_classic_world():core._oe2_world());
        this.lightMs=kind==='lit'?performance.now()-start:0;
        length=core._oe2_world_width()*core._oe2_world_height()*4*(kind==='lit'?4**this.qualityLevel:1);
      }
      else { pointer = core._oe2_frame(); length = 176 * 220 * 4; }
      return core.HEAPU8.subarray(pointer, pointer + length);
    },
    sync() {
      if (!this.persist) return;
      clearTimeout(syncTimer);
      syncTimer = setTimeout(() => this.flush(), 100);
    },
    flush() {
      if (!this.persist) return Promise.resolve(true);
      clearTimeout(syncTimer);
      syncChain = syncChain.then(() => new Promise(resolve => core.FS.syncfs(false, err => {
        this.saveError = err ? String(err) : '';
        resolve(!err);
      })));
      return syncChain;
    },
    saveNames() { return core.FS.readdir(SAVE_DIR).filter(name=>SAVE_NAME.test(name)).sort(); },
    async backupData() {
      const files={};
      for(const name of this.saveNames()){
        const bytes=core.FS.readFile(SAVE_DIR+'/'+name);let binary='';
        for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
        const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
        files[name]={data:btoa(binary),sha256:Array.from(digest,b=>b.toString(16).padStart(2,'0')).join('')};
      }
      if(!files.Config||(!files.SD_0&&!files.SD_1)||!Object.keys(files).some(n=>/^SD_[2-9]$/.test(n)))throw new Error('No complete BREW save');
      return JSON.stringify({format:'orcs-elves-ii-brew-save',version:1,game:'7.0.41',files},null,2);
    },
    async exportSave() {
      try {
        await this.flush();const data=await this.backupData();
        const filename='orcs-elves-ii-save-'+new Date().toISOString().replace(/[:.]/g,'-')+'.json';
        if(globalThis.BrewAndroid&&typeof BrewAndroid.saveBackup==='function'){
          this.backupStatus='';BrewAndroid.saveBackup(filename,data);return;
        }
        const url=URL.createObjectURL(new Blob([data],{type:'application/json'}));
        const link=document.createElement('a');link.href=url;link.download=filename;
        document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);
        this.backupStatus='Копия сохранения скачана';
      }catch(error){this.backupStatus='Не удалось скачать сохранение';console.error('Save export:',error);}
    },
    async restoreBackup(text,{load=true}={}) {
      if(text.length>8_000_000)throw new Error('Save archive is too large');
      const pack=JSON.parse(text),incoming=new Map();
      if(pack.format!=='orcs-elves-ii-brew-save'||pack.version!==1||pack.game!=='7.0.41'||!pack.files||typeof pack.files!=='object')throw new Error('Unsupported save archive');
      const names=Object.keys(pack.files);
      if(names.length>11||!pack.files.Config||(!pack.files.SD_0&&!pack.files.SD_1)||!names.some(n=>/^SD_[2-9]$/.test(n)))throw new Error('Incomplete save archive');
      for(const name of names){
        if(!SAVE_NAME.test(name))throw new Error('Unexpected save filename');
        const file=pack.files[name];if(typeof file.data!=='string'||file.data.length>2_000_000)throw new Error('Invalid save data');
        const bytes=Uint8Array.from(atob(file.data),c=>c.charCodeAt(0));
        const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
        if(Array.from(digest,b=>b.toString(16).padStart(2,'0')).join('')!==file.sha256)throw new Error('Save checksum mismatch');
        incoming.set(name,bytes);
      }
      const previous=new Map(this.saveNames().map(name=>[name,core.FS.readFile(SAVE_DIR+'/'+name)]));
      this.importing=true;clearTimeout(syncTimer);
      try {
        for(const [name,bytes] of incoming)core.FS.writeFile(SAVE_DIR+'/'+name+'.import',bytes);
        for(const name of previous.keys())if(!incoming.has(name))core.FS.unlink(SAVE_DIR+'/'+name);
        for(const name of incoming.keys())core.FS.rename(SAVE_DIR+'/'+name+'.import',SAVE_DIR+'/'+name);
        if(!await this.flush())throw new Error('Save storage unavailable');
      }catch(error){
        for(const name of this.saveNames())core.FS.unlink(SAVE_DIR+'/'+name);
        for(const [name,bytes] of previous)core.FS.writeFile(SAVE_DIR+'/'+name,bytes);
        for(const name of incoming.keys()){const temp=SAVE_DIR+'/'+name+'.import';if(core.FS.analyzePath(temp).exists)core.FS.unlink(temp);}
        await this.flush();throw error;
      }finally{this.importing=false;pendingMs=0;}
      const started=load?core._oe2_load():0;
      this.backupStatus=started?'Сохранение загружено':'Копия сохранения восстановлена';
      return true;
    },
    importSave() {
      const input=document.createElement('input');input.type='file';input.accept='.json,application/json';input.hidden=true;
      input.onchange=async()=>{
        try{if(input.files[0]){this.backupStatus='Загружаем сохранение…';await this.restoreBackup(await input.files[0].text());}}
        catch(error){this.backupStatus='Не удалось загрузить копию сохранения';console.error('Save import:',error);}
        finally{input.remove();}
      };
      input.oncancel=()=>input.remove();document.body.appendChild(input);input.click();
    },
    quality(value) { this.qualityLevel=Math.max(0,Math.min(2,Math.floor(Number(value)||0)));if(this.ready)core._oe2_quality(this.qualityLevel);try{localStorage.setItem('oe2-brew-quality',String(this.qualityLevel));}catch(_){} },
    savedQuality() { try{return Math.max(0,Math.min(2,Math.floor(Number(localStorage.getItem('oe2-brew-quality'))||0)));}catch(_){return 0;} },
    debug(value) { try{localStorage.setItem('oe2-brew-debug',value?'1':'0');}catch(_){} },
    savedDebug() { try{return localStorage.getItem('oe2-brew-debug')==='1';}catch(_){return false;} },
    graphics(value) { try { localStorage.setItem('oe2-brew-graphics',value); } catch (_) {} },
    savedGraphics() { try { return localStorage.getItem('oe2-brew-graphics')||'classic'; } catch (_) { return 'classic'; } },
    language(value) { try { localStorage.setItem('oe2-brew-ui-language', value); } catch (_) {} },
    savedLanguage() { try { return localStorage.getItem('oe2-brew-ui-language') || ''; } catch (_) { return ''; } },
  };
  if (typeof document === 'undefined') {
    Brew.testFile=name=>core.FS.readFile(SAVE_DIR+'/'+name);
    Brew.testWriteFile=(name,data)=>core.FS.writeFile(SAVE_DIR+'/'+name,data);
    Brew.testWeaponBottom=()=>core._oe2_weapon_bottom();
  }
  if (typeof document !== 'undefined') {
    document.addEventListener('keydown', event => {
      if (document.activeElement?.id === 'canvas' && ['F2','F5','F9',' ','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.key)) event.preventDefault();
    });
    document.addEventListener('visibilitychange', () => { pendingMs = 0; audio.pause(document.hidden); if (document.hidden) Brew.flush(); });
    addEventListener('pagehide', () => Brew.flush());
    Brew.init().catch(error => { Brew.error = String(error); console.error(error); });
  }
})();
