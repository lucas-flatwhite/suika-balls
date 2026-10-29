"""Check fresh and regenerated export navigation without requiring Godot."""
from pathlib import Path
import sys
from html.parser import HTMLParser
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from prepare_web import render_shell
ROOT = Path(__file__).resolve().parents[1]
class Navigation(HTMLParser):
    def __init__(self):
        super().__init__(); self.header = False; self.links = []; self.in_status = False
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get('id') == 'status': self.in_status = True
        if tag == 'header' and attrs.get('id') == 'arcade-bar':
            assert not self.in_status, 'The link must survive removal of the loading overlay'
            self.header = True
        if self.header and tag == 'a': self.links.append(attrs)
    def handle_endtag(self, tag):
        if tag == 'header': self.header = False
source = (ROOT / 'ui/web/godot.html').read_text()
for installable in (False, True):
    rendered = render_shell(source, installable=installable)
    parser = Navigation(); parser.feed(rendered)
    assert len(parser.links) == 1, 'Every export must contain one persistent header link'
    assert parser.links[0]['href'] == 'https://lucasflatwhite.com/arcade/'
    assert 'onclick' not in parser.links[0], 'Returning must work even if JavaScript or Godot fails'
    assert render_shell(rendered, installable=installable) == rendered, 'Regeneration must not duplicate navigation'
print('PASS: persistent navigation in fresh/managed/installable exports, canonical URL and idempotence')
