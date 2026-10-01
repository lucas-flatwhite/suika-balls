const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(process.argv[2],'utf8');
const early = html.match(/<script data-mushies-startup>([\s\S]*?)<\/script>/)?.[1];
assert.ok(early,'Observe engine-script transfer before startup');
const script = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map(match=>match[1]).find(code=>code.includes('const GODOT_CONFIG ='));
assert.ok(script,'Fresh export contains Godot bootstrap');
async function scenario(cancelled){
  let engineReady, finishAnimation, callbacks, removed=0, began=0, readyCalls=0;
  const enginePromise=new Promise(resolve=>engineReady=resolve);
  const animationPromise=new Promise(resolve=>finishAnimation=resolve);
  const elements={status:{style:{},remove(){removed++;}},'status-progress':{style:{}},'status-notice':{style:{}}};
  class Engine{static getMissingFeatures(){return [];}startGame(options){callbacks=options;return enginePromise;}}
  const progress=[];
  vm.runInNewContext(early+script,{Engine,Promise,console,document:{getElementById:id=>elements[id]},window:{MushiesLoader:{begin(){began++;},scriptReady(){},progress(a,b){progress.push([a,b]);},ready(){readyCalls++;return animationPromise;},failure(){}}},t:key=>key});
  assert.equal(began,1);callbacks.onProgress(2,100);assert.deepEqual(progress,[[2,100]]);
  engineReady();await Promise.resolve();await Promise.resolve();
  assert.equal(readyCalls,1);assert.equal(removed,0,'Godot cannot remove the loader before the final duck animation completes');
  finishAnimation(!cancelled);await Promise.resolve();await Promise.resolve();
  assert.equal(removed,cancelled?0:1,'Only a successfully completed handoff removes the status overlay');
}
(async()=>{await scenario(false);await scenario(true);console.log('PASS: generated Godot progress wiring, awaited final drop, and cancelled handoff protection.');})().catch(error=>{console.error(error);process.exitCode=1;});
