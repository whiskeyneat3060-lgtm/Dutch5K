// Load the app in jsdom, then inject a script that reads the built deck
// (top-level lets share the global lexical scope with later classic scripts)
// and dump every English string ct() can touch: meanings + example EN sides.
const { JSDOM } = require('jsdom');
const fs = require('fs');
const html = fs.readFileSync('/home/user/Dutch5K/public/index.html', 'utf8');

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  url: 'https://dutch5k.example/',
  pretendToBeVisual: true,
});
const { window } = dom;
window.matchMedia = window.matchMedia || (() => ({ matches: false, addListener(){}, removeListener(){} }));

setTimeout(() => {
  const s = window.document.createElement('script');
  s.textContent = `
    try {
      const meanings = new Set();
      const examples = new Set();
      deck.forEach(e => {
        if (e.m) meanings.add(e.m);
        if (Array.isArray(e.ex)) e.ex.forEach(p => { if (p && p[1]) examples.add(p[1]); });
      });
      window.__DUMP__ = JSON.stringify({
        deckSize: deck.length,
        meanings: [...meanings],
        examples: [...examples],
      });
    } catch (err) { window.__DUMP_ERR__ = String(err && err.stack || err); }
  `;
  window.document.body.appendChild(s);
  if (window.__DUMP_ERR__) { console.error(window.__DUMP_ERR__); process.exit(1); }
  const d = JSON.parse(window.__DUMP__);
  console.log('deck:', d.deckSize, 'unique meanings:', d.meanings.length, 'unique example-EN:', d.examples.length);
  const chars = [...d.meanings, ...d.examples].reduce((a, s) => a + s.length, 0);
  console.log('total source chars:', chars);
  fs.writeFileSync(__dirname + '/strings.json', JSON.stringify(d));
  process.exit(0);
}, 1500);
