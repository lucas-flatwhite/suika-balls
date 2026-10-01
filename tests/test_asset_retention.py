#!/usr/bin/env python3
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,tempfile
ROOT=Path(__file__).resolve().parents[1]
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
checker=module('retention','tools/check_asset_retention.py');archive=module('archive','tools/sync_preview_archive.py')
with tempfile.TemporaryDirectory(prefix='mushies-retention-test-') as directory:
    root=Path(directory);(root/'tools').mkdir();(root/'assets/template').mkdir(parents=True);(root/'legacy').mkdir()
    kept=root/'assets/template/keep.png';kept.write_bytes(b'fixture-only')
    font_directory=root/'assets/template/fonts';font_directory.mkdir()
    regular=font_directory/'regular.ttf';regular.write_bytes(b'approved primary font fixture')
    fallback=font_directory/'fallback.otf';fallback.write_bytes(b'approved fallback font fixture')
    policy={'retired_repository_media':['legacy/retired.png'],'retired_managed_assets':['assets/template/upstream_archive/legacy/retired.png'],'retired_sidecars':[],'upstream_font_replacement':{'retired':[],'replacement':['assets/template/fonts/regular.ttf']},'retained_asset_hashes':{str(path.relative_to(root)):'sha256:'+hashlib.sha256(path.read_bytes()).hexdigest() for path in [kept,regular,fallback]}}
    (root/'tools/asset-retirement.json').write_text(json.dumps(policy))
    with contextlib.redirect_stdout(io.StringIO()):checker.check(root)
    def rejects(expected=None):
        try:checker.check(root)
        except SystemExit as error:
            if expected is not None:assert expected in str(error),str(error)
            return
        raise AssertionError('Invalid retention state was accepted')
    # Any unapproved font in a runtime font directory is rejected, regardless of name or format.
    for name in ['unexpected.ttf','unexpected.otf','unexpected.woff','unexpected.woff2','nested/unexpected.TTF']:
        unexpected=font_directory/name;unexpected.parent.mkdir(exist_ok=True);unexpected.write_bytes(b'unapproved font fixture')
        rejects('Unapproved runtime font: '+unexpected.relative_to(root).as_posix())
        unexpected.unlink()
        with contextlib.redirect_stdout(io.StringIO()):checker.check(root)
    kept.write_bytes(b'changed');rejects();kept.write_bytes(b'fixture-only')
    (root/'assets/template/missing.png.import').write_text('orphan');rejects();(root/'assets/template/missing.png.import').unlink()
    (root/'legacy/retired.png').write_bytes(b'retired fixture');rejects()
    # Even if an old source copy and map return, archive maintenance must not recreate the retired asset.
    (root/'assets.lock.json').write_text('{}')
    (root/'preview-archive-map.json').write_text(json.dumps({'files':[{'original':'legacy/retired.png','managed_asset':'assets/template/upstream_archive/legacy/retired.png','sha256':'unused'}]}))
    with contextlib.redirect_stdout(io.StringIO()):archive.main(root)
    assert not (root/'assets/template/upstream_archive/legacy/retired.png').exists()
    assert json.loads((root/'preview-archive-map.json').read_text())['files']==[]
print('PASS: retention detects unapproved runtime fonts, changed bytes, retired files and orphan imports; valid primary/fallback fonts recover and archive maintenance cannot resurrect approved retired media.')
