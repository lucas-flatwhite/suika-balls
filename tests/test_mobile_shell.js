/* Pure Node VM contract tests; this does not launch or drive a browser. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../ui/mobile/runtime.js'), 'utf8');

function target() {
  const events = new Map();
  return {
    addEventListener(name, callback, options) {
      const callbacks = events.get(name) || [];
      callbacks.push({callback, options}); events.set(name, callbacks);
    },
    fire(name, event) { for (const {callback} of events.get(name) || []) callback(event); },
    listeners(name) { return events.get(name) || []; },
  };
}

function profile(options = {}) {
  const window = {...target(), visualViewport: options.noVisual ? undefined : {...target(), ...options.visual}};
  const document = target();
  const guard = {hidden: true};
  const guardBody = {textContent: ''};
  const button = target();
  const classes = new Set();
  const styles = new Map();
  const calls = {fullscreen: 0, lock: [], changed: 0};
  const orientation = {...target(), type: options.orientation || 'portrait-primary'};
  if (!options.unsupported) orientation.lock = async value => {
    calls.lock.push(value);
    if (options.denied) throw Error('Orientation lock denied');
    orientation.type = 'portrait-primary';
  };
  document.documentElement = {
    classList: {toggle(key, enabled) { if (enabled) classes.add(key); else classes.delete(key); }},
    style: {setProperty(key, value) { styles.set(key, value); }},
  };
  if (!options.unsupported) document.documentElement.requestFullscreen = async () => {
    calls.fullscreen++;
    if (options.denied) throw Error('Fullscreen denied');
    document.fullscreenElement = document.documentElement;
  };
  const elements = new Map();
  document.body = {appendChild(element) { elements.set(element.id, element); }};
  document.createElement = () => ({setAttribute() {}});
  document.visibilityState = options.visibility || 'visible';
  document.hidden = document.visibilityState === 'hidden';
  document.getElementById = id => elements.get(id) || ({'portrait-guard': guard, 'portrait-body': guardBody, 'portrait-action': button}[id]);
  window.mushiesDeviceChanged = () => calls.changed++;
  const context = vm.createContext({
    window, document,
    screen: {orientation},
    navigator: {userAgent: options.ua || 'iPhone', platform: options.platform || '', maxTouchPoints: options.touch || 0, userAgentData: options.data},
    innerWidth: options.width || 390, innerHeight: options.height || 844,
    getComputedStyle: () => ({paddingLeft: '0px', paddingTop: '44px', paddingRight: '0px', paddingBottom: '34px'}),
  });
  vm.runInContext(source, context);
  document.fire('DOMContentLoaded');
  return {window, document, guard, guardBody, button, classes, styles, calls, orientation, context, state: window.MushiesDevice};
}

async function run() {
  const cancellation = profile();
  const cancelListeners = cancellation.document.listeners('touchcancel');
  assert.equal(cancelListeners.length, 1, 'The shell installs one touch cancellation bridge');
  assert.equal(cancelListeners[0].options.capture, true, 'Cancellation runs before the Godot canvas target handler');
  assert.equal(cancelListeners[0].options.passive, true, 'The engine must still receive cancellation to clean up its internal touches');
  const cancelEvent = {
    preventDefault() { assert.fail('The bridge must not prevent engine touch cleanup'); },
    stopPropagation() { assert.fail('The bridge must not stop engine touch cleanup'); },
    stopImmediatePropagation() { assert.fail('The bridge must not stop other touch handlers'); },
  };
  assert.doesNotThrow(() => cancellation.document.fire('touchcancel', cancelEvent), 'Cancellation is safe before Godot registers the bridge');
  let canceled = 0;
  cancellation.window.mushiesTouchCancelled = () => canceled++;
  cancellation.document.fire('touchcancel', cancelEvent);
  assert.equal(canceled, 1, 'A browser cancellation synchronously clears gameplay ownership');
  cancellation.document.fire('touchend', {});
  assert.equal(canceled, 1, 'An ordinary touch release retains tap-to-drop behavior');
  cancellation.window.mushiesTouchCancelled = null;
  assert.doesNotThrow(() => cancellation.document.fire('touchcancel', cancelEvent), 'Cancellation is safe after the game cleans up its bridge');
  const phone = profile({orientation: 'landscape-primary', width: 844, height: 390});
  assert.equal(phone.state.mobile, true);
  assert.equal(phone.guard.hidden, false);
  phone.window.mushiesSetResizeEnded(true);
  assert.equal(phone.guard.hidden, true, 'A resize loss cannot be hidden by the orientation cover');
  const banner = phone.document.getElementById('resize-ended-banner');
  assert.equal(banner.textContent, 'CHEATER CHEATER, PANTS ON FIRE');
  assert.equal(banner.hidden, false);
  phone.window.fire('resize');
  assert.equal(phone.guard.hidden, true, 'Further resize notifications retain the visible loss banner');
  phone.window.mushiesSetResizeEnded(false);
  assert.equal(banner.hidden, true, 'Restart/title clears the banner');
  assert.equal(phone.guard.hidden, false);
  assert.deepEqual(Array.from(phone.state.safeInsets), [0,44,0,34]);
  assert.deepEqual(Array.from(phone.state.viewport), [844,390]);
  assert.equal(phone.classes.has('mobile-device'), true);
  assert.equal(phone.calls.fullscreen, 0, 'Fullscreen waits for a user gesture');
  assert.equal(phone.state.visible, true);
  assert.equal(phone.state.onlineMatch, undefined);
  assert.match(phone.guardBody.textContent, /paused/, 'Solo rotation still explains its pause');
  phone.document.fire('pointerup');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(phone.calls.fullscreen, 0, 'Starting gameplay cannot launch a late asynchronous fullscreen resize');
  phone.button.fire('click');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(phone.calls.fullscreen, 1);
  assert.deepEqual(phone.calls.lock, ['portrait']);
  assert.equal(phone.guard.hidden, true);
  phone.document.fire('pointerup');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(phone.calls.lock.length, 1, 'Ordinary taps do not repeat fullscreen requests');

  const changes = phone.calls.changed;
  phone.orientation.type = 'landscape-secondary';
  phone.orientation.fire('change');
  assert.equal(phone.state.portraitBlocked, true);
  assert.equal(phone.calls.changed, changes+1, 'Late orientation events notify the engine directly');
  phone.orientation.type = 'portrait-primary';
  phone.orientation.fire('change');
  phone.context.innerHeight = 250;
  phone.window.visualViewport.fire('resize');
  assert.equal(phone.state.viewport[1], 250, 'CSS viewport dimensions are updated independently of screen pixels');
  assert.equal(phone.state.portraitBlocked, false, 'A portrait keyboard does not masquerade as landscape');

  const ipad = profile({ua:'Safari', platform:'MacIntel', touch:5});
  assert.equal(ipad.state.mobile, true);
  const android = profile({ua:'Chrome', data:{mobile:true}});
  assert.equal(android.state.mobile, true);
  const desktop = profile({ua:'Desktop Chrome', orientation:'landscape-primary'});
  await desktop.window.mushiesEnterPortrait();
  assert.equal(desktop.state.mobile, false);
  assert.equal(desktop.guard.hidden, true);
  assert.equal(desktop.calls.fullscreen, 0);
  assert.deepEqual(desktop.calls.lock, []);

  for (const [width, height] of [[520,858], [601,1000], [768,1024], [1024,1366]]) {
    const preview = profile({ua:'Desktop Chrome', width, height});
    assert.equal(preview.classes.has('portrait-layout'), true, 'All portrait widths use a full-viewport canvas');
    assert.equal(preview.styles.get('--mushies-viewport-height'), `${height}px`);
    assert.equal(preview.guard.hidden, true, 'A desktop portrait preview does not require device detection');
  }
  const visible = profile({visual:{width:390, height:640, scale:1, offsetLeft:0, offsetTop:0}});
  assert.equal(visible.context.innerHeight, 844);
  assert.deepEqual(Array.from(visible.state.viewport), [390,640], 'Visible height can shrink while the layout viewport stays unchanged');
  assert.equal(visible.styles.get('--mushies-viewport-height'), '640px', 'The canvas and Godot share the same visible dimensions');
  visible.window.visualViewport.height = 750;
  const beforeResize = visible.calls.changed;
  visible.window.visualViewport.fire('resize');
  assert.deepEqual(Array.from(visible.state.viewport), [390,750], 'Hiding browser bars adds playable height');
  assert.equal(visible.calls.changed, beforeResize+1);
  visible.window.visualViewport.height = 250;
  visible.window.visualViewport.fire('resize');
  assert.equal(visible.state.portraitBlocked, false, 'Keyboard height cannot trigger the landscape guard');
  visible.window.visualViewport.offsetLeft = 5;
  visible.window.visualViewport.offsetTop = 100;
  visible.window.visualViewport.fire('scroll');
  assert.equal(visible.styles.get('--mushies-viewport-left'), '5px');
  assert.equal(visible.styles.get('--mushies-viewport-top'), '100px', 'A panned visual viewport keeps the canvas onscreen');
  visible.window.visualViewport.scale = 2;
  visible.window.visualViewport.fire('resize');
  assert.deepEqual(Array.from(visible.state.viewport), [390,844], 'Pinch zoom retains the layout size instead of shrinking the game');
  assert.equal(visible.styles.get('--mushies-viewport-top'), '0px');
  for (const options of [{noVisual:true}, {visual:{width:0,height:0,scale:1}}, {visual:{width:NaN,height:640,scale:1}}]) {
    const fallbackView = profile(options);
    assert.deepEqual(Array.from(fallbackView.state.viewport), [390,844], 'Missing or temporarily invalid visual metrics use the layout viewport');
  }

  for (const options of [{unsupported:true},{denied:true}]) {
    const limited = profile({...options, orientation:'landscape-primary'});
    await limited.window.mushiesEnterPortrait();
    assert.equal(limited.guard.hidden, false, 'Unsupported or denied locks retain the rotate guard');
    limited.orientation.type = 'portrait-primary';
    limited.orientation.fire('change');
    assert.equal(limited.guard.hidden, true);
  }
  const fallback = profile({unsupported:true, width:844, height:390});
  delete fallback.orientation.type;
  fallback.window.fire('resize');
  assert.equal(fallback.state.portraitBlocked, true, 'Viewport ratio is the fallback when no screen type exists');

  const live = profile({orientation:'landscape-primary'});
  assert.equal(live.window.mushiesSetOnlineMatch, undefined, 'The local template has no online match shell hook');
  assert.equal(live.state.onlineMatch, undefined);
  let changesBeforeVisibility = live.calls.changed;
  live.document.visibilityState = 'hidden';
  live.document.hidden = true;
  live.document.fire('visibilitychange');
  assert.equal(live.state.visible, false);
  assert.equal(live.calls.changed, changesBeforeVisibility+1, 'Backgrounding notifies Godot without a resize');
  live.document.fire('visibilitychange');
  assert.equal(live.calls.changed, changesBeforeVisibility+1, 'Duplicate hidden events do not repeat lifecycle transitions');
  live.document.visibilityState = 'visible';
  live.document.hidden = false;
  live.document.fire('visibilitychange');
  assert.equal(live.state.visible, true);
  assert.equal(live.calls.changed, changesBeforeVisibility+2, 'Foregrounding notifies Godot to require fresh state');
  changesBeforeVisibility = live.calls.changed;
  live.window.fire('pagehide');
  assert.equal(live.state.visible, false, 'BFCache pagehide blocks input even while document visibility still says visible');
  live.window.fire('resize');
  assert.equal(live.state.visible, false, 'Resize cannot accidentally undo pagehide');
  live.window.fire('pageshow');
  assert.equal(live.state.visible, true);
  assert.equal(live.calls.changed, changesBeforeVisibility+2, 'BFCache hide/show each publish one visibility transition');
  const initiallyHidden = profile({visibility:'hidden'});
  assert.equal(initiallyHidden.state.visible, false, 'An initially hidden tab cannot start with usable input');
  initiallyHidden.window.fire('pageshow');
  assert.equal(initiallyHidden.state.visible, false, 'pageshow does not override a still-hidden document');
  console.log('PASS: portrait previews, visible viewport sizing/panning, pinch zoom, mobile detection, safe areas, gesture gating, portrait locks, engine callbacks, keyboard, local-only shell, visibility/BFCache lifecycle, touch-cancel capture bridge and fallbacks.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
