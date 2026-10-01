/* Pure Node VM contract tests; no browser automation or production requests. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,'../ui/mobile/loader.js'),'utf8');
const css = fs.readFileSync(path.join(__dirname,'../ui/mobile/loader.css'),'utf8');
class Element {
  constructor(id='') { this.id=id;this.hidden=false;this.textContent='';this.attributes=new Map();this.style=new Map();this.style.setProperty=(k,v)=>this.style.set(k,String(v));this.events=new Map();this.children=[];this.clientWidth=0;this.clientHeight=0; }
  setAttribute(k,v){this.attributes.set(k,String(v));}
  getAttribute(k){return this.attributes.get(k)??null;}
  removeAttribute(k){this.attributes.delete(k);}
  addEventListener(k,v){this.events.set(k,v);}
  fire(k,event){this.events.get(k)?.(event);}
  appendChild(node){this.children.push(node);node.parent=this;}
  remove(){if(this.parent)this.parent.children.splice(this.parent.children.indexOf(this),1);}
}
function profile(reduced=false,domReady=true){
  const entries={};
  for(const id of ['status','mushies-loader','mushies-loader-ducks','mushies-loader-message','mushies-loader-detail','mushies-loader-progress','mushies-loader-retry'])entries[id]=new Element(id);
  const events=new Map(), windowEvents=new Map(), timers=new Map();
  let time=0,timerId=0,locale='en',reloads=0;
  const motion={matches:reduced,addEventListener(_event,fn){this.change=fn;}};
  const document={hidden:false,getElementById:id=>entries[id]||null,createElement:()=>new Element(),addEventListener:(k,v)=>events.set(k,v)};
  const window={innerWidth:390,innerHeight:844,location:{reload(){reloads++;}},matchMedia:()=>motion,addEventListener:(k,v)=>windowEvents.set(k,v),removeEventListener:k=>windowEvents.delete(k)};
  const copy={};
  for(const lang of ['en','zh_CN'])copy[lang]=JSON.parse(fs.readFileSync(path.join(__dirname,'../localization',lang+'.json'),'utf8'));
  const context=vm.createContext({window,document,performance:{now:()=>time},setTimeout(fn,ms){const id=++timerId;timers.set(id,{fn,at:time+ms,ms});return id;},clearTimeout:id=>timers.delete(id),t:key=>copy[locale][key]||key});
  vm.runInContext(source,context);if(domReady)events.get('DOMContentLoaded')();
  return {ui:entries,loader:window.MushiesLoader,window,document,motion,events,windowEvents,timers,setLocale(v){locale=v;},reloads:()=>reloads,tick(ms){time+=ms;for(const [id,timer] of [...timers])if(timer.at<=time){timers.delete(id);timer.fn();}}};
}
async function run(){
  const p=profile(), {loader,ui}=p, field=ui['mushies-loader-ducks'];
  assert.equal(ui['mushies-loader'].hidden,true);
  loader.begin();
  assert.equal(ui['mushies-loader-message'].textContent,'LOADING...');
  assert.equal(ui['mushies-loader-detail'].hidden,true);
  assert.equal(ui['mushies-loader-detail'].textContent,'');
  assert.equal(field.children.length,0);
  assert.equal(ui['mushies-loader-progress'].getAttribute('aria-valuenow'),null);
  // Every exact percentage boundary, including floating-point-sensitive 58%.
  for(let percent=0;percent<=100;percent++){
    loader.progress(percent,100);
    assert.equal(field.children.length,Math.floor(percent/2),'One duck per completed 2% at '+percent);
    assert.equal(ui['mushies-loader-progress'].getAttribute('aria-valuenow'),String(percent));
    const same=[...field.children];loader.progress(percent,100);
    assert.deepEqual(field.children,same,'Repeated callbacks do not rebuild or duplicate ducks');
  }
  assert.equal(ui['mushies-loader'].getAttribute('data-state'),'preparing');
  assert.equal(ui['mushies-loader'].hidden,false,'50 ducks means transfer complete, not game ready');
  for(const duck of field.children){assert.equal(duck.src,'loader-duck.webp');assert.equal(duck.alt,'');assert.equal(duck.getAttribute('aria-hidden'),'true');}
  loader.progress(20,100);assert.equal(field.children.length,50,'Late regressive callbacks retain already reached milestones');
  const ready=loader.ready();assert.equal(ready,loader.ready(),'Ready has one timer/promise');
  assert.equal(field.children.length,50);assert.equal(p.timers.size,1);
  assert.ok([...p.timers.values()][0].ms<=1100,'Cached/burst animation cannot block startup indefinitely');
  p.tick(1100);
  assert.equal(ui['mushies-loader'].getAttribute('data-state'),'fading');
  assert.equal(ui.status.getAttribute('data-mushies-fade'),'true','Outer opaque status layer fades with the ducks');
  assert.equal(ui['mushies-loader'].hidden,false,'Keep loading layer alive throughout the fade');
  ui.status.fire('animationend',{target:field,animationName:'mushies-duck-drop'});
  p.tick(180);assert.equal(ui['mushies-loader'].hidden,false,'A half-fade cannot release input or remove the ducks');
  ui.status.fire('animationend',{target:ui.status,animationName:'mushies-loader-fade'});
  assert.equal(p.timers.size,0,'Animation completion cancels the bounded fallback');
  assert.equal(await ready,true);assert.equal(ui['mushies-loader'].hidden,true);assert.equal(field.children.length,0,'Ready releases all transient images');
  loader.progress(50,100);loader.failure();assert.equal(ui['mushies-loader'].hidden,true,'Late callbacks cannot resurrect a completed loader');
  loader.begin();loader.progress(39,100);assert.equal(field.children.length,19);
  loader.progress(0,0);assert.equal(field.children.length,19,'Unknown totals add no invented ducks');
  assert.equal(ui['mushies-loader-progress'].getAttribute('aria-valuenow'),null);
  loader.progress(NaN,Infinity);assert.equal(field.children.length,19);
  p.setLocale('zh_CN');loader.refresh();assert.equal(ui['mushies-loader-message'].textContent,'加载中…');
  loader.failure();assert.equal(ui['mushies-loader-retry'].hidden,false);assert.equal(ui['mushies-loader-detail'].hidden,false);
  assert.match(ui['mushies-loader-message'].textContent,/无法/);
  loader.progress(100,100);assert.equal(ui['mushies-loader'].getAttribute('data-state'),'failure','Late network callbacks cannot erase errors');
  ui['mushies-loader-retry'].fire('click');assert.equal(p.reloads(),1);
  loader.begin();assert.equal(field.children.length,0,'A new load resets the milestone set');
  const cached=loader.ready();assert.equal(field.children.length,50,'Engine ready proves completion for cached/unknown-length transfers');
  loader.failure();assert.equal(await cached,false);assert.equal(p.timers.size,0,'Failure cancels the finishing timer');
  const pendingScript=profile(false,false);pendingScript.loader.begin();pendingScript.tick(130000);
  assert.equal(pendingScript.ui['mushies-loader'].hidden,false);assert.equal(pendingScript.ui['mushies-loader-retry'].hidden,false);assert.match(pendingScript.ui['mushies-loader-detail'].textContent,/No recent/);
  pendingScript.ui['mushies-loader-retry'].fire('click');assert.equal(pendingScript.reloads(),1,'Retry works while a blocking script still prevents DOMContentLoaded');
  pendingScript.loader.scriptReady();assert.match(pendingScript.ui['mushies-loader-detail'].textContent,/Still loading/);pendingScript.tick(30000);pendingScript.loader.scriptReady();assert.match(pendingScript.ui['mushies-loader-detail'].textContent,/No recent/);
  const scriptReady=pendingScript.loader.ready();pendingScript.tick(1100);pendingScript.tick(420);assert.equal(await scriptReady,true);
  const slow=profile();slow.loader.begin();
  for(let bytes=10;bytes<=80;bytes+=10){slow.loader.progress(bytes,100);slow.tick(20000);}
  assert.match(slow.ui['mushies-loader-detail'].textContent,/Still loading/);
  assert.equal(slow.ui['mushies-loader-retry'].hidden,false);
  assert.equal(slow.ui['mushies-loader-progress'].getAttribute('aria-valuenow'),'80');
  slow.tick(10000);slow.loader.progress(80,100);
  assert.match(slow.ui['mushies-loader-detail'].textContent,/No recent/);
  slow.loader.progress(81,0);assert.match(slow.ui['mushies-loader-detail'].textContent,/Still loading/);
  slow.tick(30000);slow.loader.progress(81,81);assert.match(slow.ui['mushies-loader-detail'].textContent,/Still loading/);
  slow.tick(30000);slow.loader.progress(81,81);assert.match(slow.ui['mushies-loader-detail'].textContent,/No recent/);
  const lateReady=slow.loader.ready();assert.equal(slow.ui['mushies-loader-retry'].hidden,true);slow.tick(1100);slow.tick(420);assert.equal(await lateReady,true);assert.equal(slow.timers.size,0);
  const stalledFailure=profile();stalledFailure.loader.begin();stalledFailure.tick(130000);stalledFailure.loader.failure();
  const errorCopy=stalledFailure.ui['mushies-loader-detail'].textContent;stalledFailure.tick(130000);stalledFailure.loader.progress(100,100);
  assert.equal(stalledFailure.ui['mushies-loader-detail'].textContent,errorCopy);assert.equal(stalledFailure.timers.size,0);assert.equal(await stalledFailure.loader.ready(),false);
  for(const event of ['error','unhandledrejection']){const e=profile();e.loader.begin();e.tick(130000);e.windowEvents.get(event)();assert.equal(e.ui['mushies-loader'].getAttribute('data-state'),'failure');assert.equal(e.timers.size,0);assert.equal(await e.loader.ready(),false);}
  const r=profile(true);r.loader.begin();r.loader.progress(100,100);const reducedReady=r.loader.ready();
  assert.equal([...r.timers.values()][0].ms,80);r.tick(80);assert.equal(await reducedReady,true);
  const bg=profile();bg.loader.begin();const backgroundReady=bg.loader.ready();bg.document.hidden=true;bg.events.get('visibilitychange')();assert.equal(await backgroundReady,true);assert.equal(bg.timers.size,0);
  const change=profile();change.loader.begin();const changed=change.loader.ready();change.motion.matches=true;change.motion.change();assert.equal(await changed,true);
  const fallback=profile();fallback.loader.begin();const fallbackReady=fallback.loader.ready();fallback.tick(1100);fallback.tick(420);assert.equal(await fallbackReady,true,'Missing animationend cannot strand startup');
  const failedFade=profile();failedFade.loader.begin();const old=failedFade.loader.ready();failedFade.tick(1100);failedFade.loader.failure();assert.equal(await old,false);assert.equal(failedFade.ui.status.getAttribute('data-mushies-fade'),null,'Failure restores opaque recovery UI');assert.equal(failedFade.timers.size,0);
  const resetFade=profile();resetFade.loader.begin();const previous=resetFade.loader.ready();resetFade.tick(1100);resetFade.loader.begin();assert.equal(await previous,false);assert.equal(resetFade.ui.status.getAttribute('data-mushies-fade'),null);resetFade.tick(10000);assert.equal(resetFade.ui['mushies-loader'].getAttribute('data-state'),'downloading');
  const hiddenFade=profile();hiddenFade.loader.begin();const hiddenReady=hiddenFade.loader.ready();hiddenFade.tick(1100);hiddenFade.document.hidden=true;hiddenFade.events.get('visibilitychange')();assert.equal(await hiddenReady,true);assert.equal(hiddenFade.timers.size,0);
  assert.match(css,/#status\[data-mushies-fade="true"\]\{animation:mushies-loader-fade/);
  assert.match(css,/@keyframes mushies-loader-fade\{from\{opacity:1\}to\{opacity:0\}\}/);
  // Responsive reflow changes positions, not duck count or identities.
  const resize=profile();resize.loader.begin();resize.loader.progress(100,100);const kept=[...resize.ui['mushies-loader-ducks'].children];
  resize.window.innerWidth=1440;resize.window.innerHeight=900;resize.windowEvents.get('resize')();assert.deepEqual(resize.ui['mushies-loader-ducks'].children,kept);
  for(const [w,h] of [[296,544],[366,820],[776,366],[776,576],[1000,744],[1416,876],[1896,1056]]){
    const positions=loader.layout(w,h);assert.equal(positions.length,50);
    for(const a of positions){assert.ok(a.x>=0&&a.y>=0&&a.x+a.size<=w&&a.y+a.size<=h,`Duck inside ${w}x${h}`);}
    for(let i=0;i<50;i++)for(let j=i+1;j<50;j++){
      const a=positions[i],b=positions[j];
      assert.ok(a.x+a.size<=b.x||b.x+b.size<=a.x||a.y+a.size<=b.y||b.y+b.size<=a.y,'All fifty ducks have distinct visible resting positions');
    }
  }
  assert.match(css,/@media \(prefers-reduced-motion:reduce\)/);
  assert.match(css,/env\(safe-area-inset-top\)/);assert.match(css,/env\(safe-area-inset-left\)/);
  assert.match(css,/#status-splash,#status-progress,#status-notice\{display:none!important\}/,'No duplicate Godot mascot or labels');
  assert.match(css,/@keyframes mushies-duck-drop/);
  assert.match(css,/#mushies-loader-message\{[^}]*font-size:clamp\(36px,9vw,112px\)/);
  assert.doesNotMatch(css,/mushies-loader-bar|mushies-loader-mascot/);
  assert.match(css,/font:16px\/1\.4 \"Noto Sans SC\"/);
  assert.doesNotMatch(css,/system-ui|Arial|ui-rounded/);
  console.log('PASS: all 2% thresholds, 50-duck cap, true progress, unknown/cache paths, bounded ready handoff, cleanup, retries, EN/CN, reduced motion, safe areas and seven non-overlapping responsive layouts.');
}
run().catch(error=>{console.error(error);process.exitCode=1;});
