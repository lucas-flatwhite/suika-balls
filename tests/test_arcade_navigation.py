"""Check fresh and regenerated export navigation without requiring Godot."""
from pathlib import Path
import re
import sys
from html.parser import HTMLParser
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from prepare_web import render_shell
ROOT = Path(__file__).resolve().parents[1]
class Navigation(HTMLParser):
    def __init__(self):
        super().__init__(); self.links = []; self.in_status = False; self.headers = 0
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get('id') == 'status': self.in_status = True
        if tag == 'header': self.headers += 1
        if tag == 'a' and attrs.get('id') == 'arcade-back':
            assert not self.in_status, 'The link must survive removal of the loading overlay'
            self.links.append(attrs)
source = (ROOT / 'ui/web/godot.html').read_text()
for installable in (False, True):
    rendered = render_shell(source, installable=installable)
    parser = Navigation(); parser.feed(rendered)
    assert len(parser.links) == 1, 'Every export must contain one persistent Arcade chip'
    link = parser.links[0]
    assert link['href'] == 'https://www.lucasflatwhite.com/arcade/'
    assert link['class'] == 'arcade-chip' and link['aria-label'] == 'Back to Arcade'
    assert 'onclick' not in link, 'Returning must work even if JavaScript or Godot fails'
    assert parser.headers == 0, 'No header band takes height from the game'
    assert '<span class="arcade-chip-label">Arcade</span>' in rendered
    assert render_shell(rendered, installable=installable) == rendered, 'Regeneration must not duplicate navigation'
css = (ROOT / 'ui/web/arcade.css').read_text()
chip = css[css.index('/* arcade-chip:start */'):css.index('/* arcade-chip:end */')]
for rule in ('width: 96px;', 'height: 36px;', 'inset: -4px 0;', '@media (max-width: 479.98px)', 'width: 44px;'):
    assert rule in chip, f'The chip must match flatwhite-arcade src/shared/arcade-chip.css: {rule}'
assert 'max(12px, env(safe-area-inset-left))' in css and 'max(8px, env(safe-area-inset-top))' in css, 'The chip sits where every Arcade game puts it'
assert 'arcade-bar-height' not in css, 'The canvas starts at the top of the viewport'
assert re.search(r"font-family: 'Anybody Variable';[^}]*url\(data:font/woff2;base64,", css), 'The chip label ships its own font'
assert (ROOT / 'ui/web/Anybody-OFL.txt').is_file(), 'The chip font keeps its license'
print('PASS: persistent Arcade chip in fresh/managed/installable exports, canonical URL, shared chip rules and idempotence')
