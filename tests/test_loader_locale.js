/* Pure Node VM contract test for the Web loader's start language; no browser automation or production requests.
   Order: the choice made anywhere on lucasflatwhite.com (lucas-flatwhite:locale), then this game's own (plushie_locale), then English.
   The browser language is not used. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const shell = fs.readFileSync(path.join(__dirname,'../ui/web/shell.html'),'utf8');
const start = shell.indexOf('const PLUSHIE_COPY=');
const end = shell.indexOf('function t(', start);
assert.ok(start > 0 && end > start, 'loader locale block is present in ui/web/shell.html');
const block = shell.slice(start, end) + '\nglobalThis.result = plushieLocale;';

function startLocale(store, {languages=['ko-KR'], blocked=false}={}) {
  const localStorage = {getItem(key){ if (blocked) throw new Error('blocked'); return Object.hasOwn(store,key) ? store[key] : null; }};
  const context = vm.createContext({localStorage, navigator:{languages, language:languages[0]}});
  vm.runInContext(block, context);
  return context.result;
}

assert.equal(startLocale({}), 'en', 'nothing chosen: English, even in a Korean browser');
assert.equal(startLocale({}, {blocked:true}), 'en', 'blocked storage: English');
assert.equal(startLocale({'plushie_locale':'ko'}), 'ko', "this game's own choice is used without a site choice");
assert.equal(startLocale({'lucas-flatwhite:locale':'ko'}), 'ko', 'site choice: Korean');
assert.equal(startLocale({'lucas-flatwhite:locale':'en','plushie_locale':'ko'}), 'en', "site choice wins over this game's own");
assert.equal(startLocale({'lucas-flatwhite:locale':'ko','plushie_locale':'en'}), 'ko', "site choice wins over this game's own");
assert.equal(startLocale({'lucas-flatwhite:locale':'zh_CN','plushie_locale':'ko'}), 'ko', 'unknown site value falls through');
assert.equal(startLocale({'lucas-flatwhite:locale':'toString'}), 'en', 'prototype names are not locales');
console.log('PASS: loader start language');
