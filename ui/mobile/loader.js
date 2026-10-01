/* Native Godot byte progress owns duck count; animation never fabricates downloads. */
(() => {
  const LIMIT = 50;
  const DROP_MS = 760;
  const FADE_MS = 360;
  const STAGGER_MS = 5;
  const motion = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  const ducks = [];
  let phase = 'idle', percent = null, highWater = 0;
  let slowNotice = '', retryBound = false;
  let slowTimer = null, startedAt = 0, lastProgressAt = 0, downloadedBytes = 0, downloadComplete = false, engineScriptReady = false;
  let animationEnds = 0, readyTimer = null, readyPromise = null, resolveReady = null;
  const ids = {root:'mushies-loader', field:'mushies-loader-ducks', message:'mushies-loader-message', detail:'mushies-loader-detail', progress:'mushies-loader-progress', retry:'mushies-loader-retry'};
  const copy = key => typeof t === 'function' ? t(key) : key;
  const now = () => performance.now();
  function nodes() {
    const ui = Object.fromEntries(Object.entries(ids).map(([key,id]) => [key,document.getElementById(id)]));
    return Object.values(ui).every(Boolean) ? ui : null;
  }
  function layout(width, height) {
    const cols = width >= height ? 10 : 5;
    const rows = LIMIT / cols;
    const pad = Math.min(24, Math.max(8, Math.min(width,height) * .04));
    const cellX = (width-pad*2)/cols, cellY = (height-pad*2)/rows;
    const size = Math.max(1,Math.min(128,cellX*.86,cellY*.9));
    return Array.from({length:LIMIT}, (_,i) => {
      const row = Math.floor(i/cols), col = (i%cols*3)%cols;
      const shift = row%2 ? cellX*.1 : -cellX*.1;
      const x = Math.max(pad,Math.min(width-pad-size,pad+cellX*(col+.5)-size/2+shift));
      const y = Math.max(pad,height-pad-size-row*cellY);
      return {x,y,size,angle:(i*17)%19-9};
    });
  }
  function positionDucks() {
    const ui = nodes();
    if (!ui) return;
    const places = layout(ui.field.clientWidth || window.innerWidth,ui.field.clientHeight || window.innerHeight);
    ducks.forEach((duck,i) => {
      const p = places[i];
      for (const [key,value] of Object.entries({x:p.x+'px',y:p.y+'px',size:p.size+'px',angle:p.angle+'deg'})) duck.style.setProperty('--duck-'+key,value);
    });
  }
  function addDucks(target) {
    const ui = nodes();
    if (!ui) return;
    const first = ducks.length;
    while (ducks.length < Math.min(LIMIT,target)) {
      const duck = document.createElement('img');
      duck.className = 'mushies-loader-duck';
      duck.src = 'loader-duck.webp';
      duck.alt = '';
      duck.draggable = false;
      duck.setAttribute('aria-hidden','true');
      const delay = (ducks.length-first)*STAGGER_MS;
      duck.style.setProperty('--duck-delay',delay+'ms');
      duck.style.setProperty('--duck-duration',DROP_MS+'ms');
      ui.field.appendChild(duck);
      ducks.push(duck);
      animationEnds = Math.max(animationEnds,now()+DROP_MS+delay);
    }
    positionDucks();
  }
  function clearDucks() {
    for (const duck of ducks) duck.remove();
    ducks.length = 0;
    animationEnds = 0;
  }
  function cancelReady() {
    if (readyTimer !== null) clearTimeout(readyTimer);
    readyTimer = null;
    if (resolveReady) resolveReady(false);
    resolveReady = null;
    readyPromise = null;
    document.getElementById('status')?.removeAttribute('data-mushies-fade');
  }
  function stopWatch() {
    if (slowTimer !== null) clearTimeout(slowTimer);
    slowTimer = null;
  }
  function currentNotice() {
    if (!['downloading','preparing'].includes(phase) || now()-startedAt < 30000) return '';
    return now()-lastProgressAt >= 30000 ? 'loader.stalled_notice' : 'loader.loading_notice';
  }
  function watch() {
    if (!['downloading','preparing'].includes(phase)) return;
    if (currentNotice() !== slowNotice) render();
    slowTimer = setTimeout(watch,1000);
  }
  function render() {
    const ui = nodes();
    if (!ui) return;
    ui.root.hidden = phase === 'idle' || phase === 'ready';
    ui.root.setAttribute('data-state',phase);
    ui.root.setAttribute('aria-busy',String(!['idle','ready','failure'].includes(phase)));
    ui.message.textContent = copy(phase === 'failure' ? 'loader.error' : 'loader.overlay_loading');
    slowNotice = currentNotice();
    const slow = !!slowNotice;
    ui.detail.hidden = phase !== 'failure' && !slow;
    ui.detail.textContent = phase === 'failure' ? copy('loader.error_detail') : slow ? copy(slowNotice) : '';
    ui.retry.hidden = phase !== 'failure' && !slow;
    ui.retry.textContent = copy('loader.retry');
    ui.progress.setAttribute('aria-label',copy('loader.progress_label'));
    ui.progress.setAttribute('aria-valuemin','0');
    ui.progress.setAttribute('aria-valuemax','100');
    if (percent !== null && phase !== 'failure') ui.progress.setAttribute('aria-valuenow',String(percent));
    else ui.progress.removeAttribute('aria-valuenow');
    ui.progress.setAttribute('aria-valuetext',copy(phase === 'failure' ? 'loader.error_detail' : phase === 'preparing' || ['finishing','fading'].includes(phase) ? 'loader.preparing_detail' : percent === null ? 'loader.progress_unknown' : 'loader.downloading'));
  }
  function bindRetry() {
    const retry = nodes()?.retry;
    if (!retry || retryBound) return;
    retryBound = true;
    retry.addEventListener('click',() => window.location.reload());
  }
  function begin() {
    cancelReady(); clearDucks(); stopWatch(); bindRetry();
    document.getElementById('status')?.style.setProperty('visibility','visible');
    phase = 'downloading'; percent = null; highWater = 0;
    startedAt = now(); lastProgressAt = startedAt; downloadedBytes = 0; downloadComplete = false; engineScriptReady = false;
    window.addEventListener('error',onStartupError);
    window.addEventListener('unhandledrejection',onStartupError);
    render(); watch();
  }
  function scriptReady() {
    if (!['downloading','preparing'].includes(phase) || engineScriptReady) return;
    engineScriptReady = true; lastProgressAt = now(); render();
  }
  function progress(current,total) {
    if (['idle','failure','finishing','fading','ready'].includes(phase)) return;
    if (Number.isFinite(current) && current > downloadedBytes) {
      downloadedBytes = current; lastProgressAt = now();
    }
    if (!downloadComplete && Number.isFinite(total) && total > 0 && Number.isFinite(current) && current >= total) {
      downloadComplete = true; lastProgressAt = now();
    }
    if (Number.isFinite(current) && Number.isFinite(total) && current >= 0 && total > 0) {
      // Retain completed milestones across repeated callbacks/late total revisions.
      highWater = Math.max(highWater,Math.min(100,Math.floor(current*100/total)));
      percent = highWater;
      phase = highWater === 100 ? 'preparing' : 'downloading';
      addDucks(Math.floor(highWater/2));
    } else {
      percent = null;
      if (phase !== 'preparing') phase = 'downloading';
    }
    render();
  }
  function preparing() {
    if (['idle','failure','finishing','fading','ready'].includes(phase)) return;
    if (!downloadComplete) { downloadComplete = true; lastProgressAt = now(); }
    phase = 'preparing'; render();
  }
  const onStartupError = () => failure();
  function stopObserving() {
    window.removeEventListener('error',onStartupError);
    window.removeEventListener('unhandledrejection',onStartupError);
  }
  function failure() {
    if (phase === 'ready') return;
    stopWatch(); stopObserving(); cancelReady(); phase = 'failure'; percent = null; render();
  }
  function finishReady() {
    if (!['finishing','fading'].includes(phase)) return;
    if (readyTimer !== null) clearTimeout(readyTimer);
    readyTimer = null; phase = 'ready'; render(); clearDucks();
    const resolve = resolveReady; resolveReady = null;
    resolve?.(true);
  }
  function startFade() {
    readyTimer = null;
    const overlay = document.getElementById('status');
    if (document.hidden || motion?.matches || !overlay) { finishReady(); return; }
    phase = 'fading'; render();
    // Fade the OUTER Godot status layer too, so its opaque background cannot
    // conceal the live title canvas. Keep it input-blocking until completion.
    overlay.style.setProperty('--mushies-fade-duration',FADE_MS+'ms');
    overlay.setAttribute('data-mushies-fade','true');
    readyTimer = setTimeout(finishReady,FADE_MS+60);
  }
  function ready() {
    if (phase === 'ready') return Promise.resolve(true);
    if (phase === 'failure') return Promise.resolve(false);
    if (readyPromise) return readyPromise;
    stopWatch(); stopObserving();
    // startGame resolving is proof that cached/unknown-length downloads completed.
    percent = 100; highWater = 100; phase = 'finishing'; addDucks(LIMIT); render();
    readyPromise = new Promise(resolve => { resolveReady = resolve; });
    const delay = document.hidden ? 0 : motion?.matches ? 80 : Math.min(1100,Math.max(80,animationEnds-now()+90));
    readyTimer = setTimeout(startFade,delay);
    return readyPromise;
  }
  window.addEventListener('error',onStartupError);
  window.addEventListener('unhandledrejection',onStartupError);
  window.MushiesLoader = {begin,scriptReady,progress,preparing,failure,ready,refresh:render,layout};
  window.addEventListener('resize',positionDucks);
  document.addEventListener('visibilitychange',() => { if (document.hidden && ['finishing','fading'].includes(phase)) { if (readyTimer !== null) clearTimeout(readyTimer); finishReady(); } });
  motion?.addEventListener?.('change',() => { if (motion.matches && ['finishing','fading'].includes(phase)) { if (readyTimer !== null) clearTimeout(readyTimer); finishReady(); } });
  document.addEventListener('DOMContentLoaded',() => {
    document.getElementById('status')?.addEventListener('animationend',event => {
      if (event.target === document.getElementById('status') && event.animationName === 'mushies-loader-fade' && phase === 'fading') finishReady();
    });
    bindRetry();
    render(); positionDucks();
  });
})();
