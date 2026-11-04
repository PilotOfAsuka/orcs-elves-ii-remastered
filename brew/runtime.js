/* Browser host for the BREW C engine. Godot owns presentation and input;
 * this module owns the fixed-step simulation, persistent files and audio. */
(() => {
  'use strict';
  const base = typeof document !== 'undefined' ? new URL('.', document.currentScript.src).href : '';
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
    ready: false, error: '', saveError: '', paused: false, tickMs: 0, maxTickMs: 0,
    async init({ persist = typeof document !== 'undefined', seed } = {}) {
      if (this.ready) return this;
      core = await globalThis.createBrewModule({ locateFile: file => base + file });
      core.FS.mkdir('/oe2-brew-v1');
      this.persist = persist;
      if (persist) {
        core.FS.mount(core.IDBFS, {}, '/oe2-brew-v1');
        await new Promise((resolve, reject) => core.FS.syncfs(true, err => err ? reject(err) : resolve()));
      }
      if (seed !== undefined) core._oe2_test_seed(seed);
      const result = core.ccall('oe2_boot', 'number', ['string', 'number', 'number'], ['/gamedata', 176, 220]);
      if (result !== 0) throw new Error(`BREW startup failed (${result})`);
      this.ready = true;
      return this;
    },
    advance(ms) {
      if (!this.ready || this.paused || (typeof document !== 'undefined' && document.hidden)) { pendingMs = 0; return; }
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
          console.info('BREW performance', JSON.stringify({ticks:state.ticks,state:state.state,tickMs:this.tickMs,maxTickMs:this.maxTickMs,world:`${state.world_width}x${state.world_height}`}));
        }
      }
    },
    json() { return this.ready ? core.UTF8ToString(core._oe2_json()) : '{}'; },
    key(avk) { if (this.ready) { audio.unlock(); core._oe2_key(avk); } },
    action(action) { if (this.ready) this.key(core._oe2_action_key(action)); },
    menu(id, index) { if (this.ready) { audio.unlock(); return core._oe2_menu_select(id, index); } return 0; },
    choice(index) { if (this.ready) { audio.unlock(); core._oe2_choice(index); } },
    save() { return this.ready ? core._oe2_save() : 0; },
    load() { return this.ready ? core._oe2_load() : 0; },
    inventory() { if (this.ready) core._oe2_inventory(); },
    image(kind) {
      let pointer, length;
      if (kind === 'story') { pointer = core._oe2_story(); length = 176 * 176 * 4; }
      else if (kind === 'world') { pointer = core._oe2_world(); length = core._oe2_world_width() * core._oe2_world_height() * 4; }
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
    language(value) { try { localStorage.setItem('oe2-brew-ui-language', value); } catch (_) {} },
    savedLanguage() { try { return localStorage.getItem('oe2-brew-ui-language') || ''; } catch (_) { return ''; } },
  };
  if (typeof document === 'undefined') Brew.testFile = name => core.FS.readFile('/oe2-brew-v1/' + name);
  if (typeof document !== 'undefined') {
    document.addEventListener('keydown', event => {
      if (document.activeElement?.id === 'canvas' && ['F2','F5','F9',' ','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.key)) event.preventDefault();
    });
    document.addEventListener('visibilitychange', () => { pendingMs = 0; audio.pause(document.hidden); if (document.hidden) Brew.flush(); });
    addEventListener('pagehide', () => Brew.flush());
    Brew.init().catch(error => { Brew.error = String(error); console.error(error); });
  }
})();
