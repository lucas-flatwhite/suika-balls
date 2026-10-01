/* Device detection, safe areas and user-gesture portrait/fullscreen requests. */
(() => {
  const handheld = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
    || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
    || navigator.userAgentData?.mobile === true;
  const state = window.MushiesDevice = {mobile: handheld, portraitBlocked: false, safeInsets: [0, 0, 0, 0], viewport: [innerWidth, innerHeight], visible: true};
  let pageHidden = false;
  let guardLocale = navigator.language || 'en';
  let probe;
  let resizeEnded = false;
  let resizeBanner;

  function syncGuardCopy() {
    const body = document.getElementById('portrait-body');
    if (!body) return;
    const key = 'mobile.rotate_body';
    const localized = typeof t === 'function' ? t(key) : key;
    if (localized !== key) {
      body.textContent = localized;
    } else if (guardLocale.startsWith('zh')) {
      body.textContent = '请将设备转为竖屏。你的游戏已暂停，转回后即可继续。';
    } else {
      body.textContent = 'Turn your device to portrait. Your game is paused and will resume when you rotate back.';
    }
  }

  function viewport() {
    const visual = window.visualViewport;
    // Follow browser bars and keyboards without undoing a user's pinch zoom.
    const visible = visual && Math.abs(visual.scale - 1) < 0.01
      && Number.isFinite(visual.width) && visual.width > 0
      && Number.isFinite(visual.height) && visual.height > 0;
    return {
      width: Math.max(1, Math.round(visible ? visual.width : innerWidth)),
      height: Math.max(1, Math.round(visible ? visual.height : innerHeight)),
      left: visible && Number.isFinite(visual.offsetLeft) ? visual.offsetLeft : 0,
      top: visible && Number.isFinite(visual.offsetTop) ? visual.offsetTop : 0,
    };
  }

  function sync() {
    const previous = JSON.stringify(state);
    state.visible = !pageHidden && document.visibilityState !== 'hidden' && document.hidden !== true;
    const view = viewport();
    state.viewport = [view.width, view.height];
    const root = document.documentElement;
    for (const key of ['width', 'height', 'left', 'top']) {
      root.style.setProperty(`--mushies-viewport-${key}`, `${view[key]}px`);
    }
    const landscape = screen.orientation?.type
      ? screen.orientation.type.startsWith('landscape') : innerWidth > innerHeight;
    state.portraitBlocked = state.mobile && landscape;
    root.classList.toggle('mobile-device', state.mobile);
    root.classList.toggle('portrait-layout', view.width < view.height);
    const guard = document.getElementById('portrait-guard');
    if (guard) guard.hidden = resizeEnded || !state.portraitBlocked;
    syncGuardCopy();
    if (probe) {
      const style = getComputedStyle(probe);
      state.safeInsets = [style.paddingLeft, style.paddingTop, style.paddingRight, style.paddingBottom].map(value => parseFloat(value) || 0);
    }
    // Orientation events can arrive after the canvas resize notification.
    if (previous !== JSON.stringify(state)) window.mushiesDeviceChanged?.();
  }

  async function enterPortrait() {
    if (!state.mobile) return;
    try {
      if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen({navigationUI: 'hide'});
      }
    } catch (_) { /* The game remains playable in the full available viewport. */ }
    try { if (screen.orientation?.lock) await screen.orientation.lock('portrait'); }
    catch (_) { /* Browsers without orientation lock use the portrait guard. */ }
    sync();
  }

  window.mushiesSetResizeEnded = ended => {
    resizeEnded = Boolean(ended);
    if (!resizeBanner && document.body) {
      resizeBanner = document.createElement('div');
      resizeBanner.id = 'resize-ended-banner';
      resizeBanner.setAttribute('role', 'alert');
      resizeBanner.textContent = 'CHEATER CHEATER, PANTS ON FIRE';
      document.body.appendChild(resizeBanner);
    }
    if (resizeBanner) resizeBanner.hidden = !resizeEnded;
    const guard = document.getElementById('portrait-guard');
    if (guard) guard.hidden = resizeEnded || !state.portraitBlocked;
  };
  window.mushiesEnterPortrait = enterPortrait;
  window.addEventListener('resize', sync);
  // BFCache and background tabs can suspend Godot without a canvas resize.
  // Publish visibility immediately so solo play pauses safely on return.
  window.addEventListener('pagehide', () => { pageHidden = true; sync(); });
  window.addEventListener('pageshow', () => { pageHidden = false; sync(); });
  document.addEventListener('visibilitychange', sync);
  // Godot Web treats touchcancel as touchend. Cancel gameplay ownership before
  // its canvas handler runs, while still letting Godot clean up its touch state.
  document.addEventListener('touchcancel', () => window.mushiesTouchCancelled?.(), {capture: true, passive: true});
  window.visualViewport?.addEventListener('resize', sync);
  window.visualViewport?.addEventListener('scroll', sync);
  screen.orientation?.addEventListener('change', sync);
  document.addEventListener('fullscreenchange', sync);
  // Fullscreen is explicit: an asynchronous first-gesture request could resize
  // after Start has begun a run and immediately trigger its resize rule.
  document.addEventListener('DOMContentLoaded', () => {
    probe = document.createElement('div');
    probe.id = 'safe-area-probe';
    document.body.appendChild(probe);
    const button = document.getElementById('portrait-action');
    button?.addEventListener('click', enterPortrait);
    sync();
  });
  sync();
})();
