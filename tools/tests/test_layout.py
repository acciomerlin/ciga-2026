"""Regression checks for moving games without changing their content."""
import importlib.util
import json
import re
import threading
import unittest
from functools import partial
from html.parser import HTMLParser
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urljoin, urlsplit, unquote
from urllib.request import urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('workspace_server', ROOT / 'tools/serve.py')
server_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_module)


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.entries = []
        self.redirect = None
        self.return_menu = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and 'entry-number' in attrs.get('class', '').split():
            self.entries.append(attrs['href'])
        if tag == 'meta' and attrs.get('http-equiv', '').lower() == 'refresh':
            self.redirect = attrs['content'].split('url=', 1)[1]
        if tag == 'a' and attrs.get('id') == 'returnMenu':
            self.return_menu = attrs['href']


class LayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        handler = partial(server_module.Handler, directory=str(ROOT))
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}/'

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def fetch(self, route):
        try:
            response = urlopen(urljoin(self.base, route), timeout=5)
        except HTTPError as error:
            error.close()
            self.fail(f'{route}: HTTP {error.code}')
        with response:
            self.assertEqual(response.status, 200)
            self.assertEqual(response.headers['Cross-Origin-Opener-Policy'], 'same-origin')
            self.assertEqual(response.headers['Cross-Origin-Embedder-Policy'], 'require-corp')
            return response.read().decode('utf-8')

    def test_root_opens_the_shared_menu(self):
        root = Page()
        root.feed(self.fetch('/'))
        self.assertIsNotNone(root.redirect)
        menu = Page()
        menu.feed(self.fetch(root.redirect))
        self.assertEqual(len(menu.entries), 3)
        destinations = [urlsplit(urljoin(root.redirect, href)).path for href in menu.entries]
        self.assertEqual(destinations, [
            'dist/anchorshackeshacke/index.html',
            'dist/help-ai-anchorman/index.html',
            'games/03-anchor-drift/web/index.html',
        ])
        self.fetch(destinations[2])

    def test_each_game_has_its_editable_source(self):
        for relative in (
            'games/01-ship/godot/project.godot',
            'games/02-ai-anchorman/godot/project.godot',
            'games/03-anchor-drift/web/game.js',
        ):
            with self.subTest(source=relative):
                self.assertTrue((ROOT / relative).is_file(), relative)

    def test_river_game_can_return_to_the_shared_menu(self):
        route = 'games/03-anchor-drift/web/index.html'
        game = Page()
        game.feed(self.fetch(route))
        self.assertIsNotNone(game.return_menu)
        menu = Page()
        menu.feed(self.fetch(urljoin(route, game.return_menu)))
        self.assertEqual(len(menu.entries), 3)

    def test_alternate_web_versions_and_prototypes_remain_reachable(self):
        for route in (
            'games/02-ai-anchorman/web/index.html',
            'games/02-ai-anchorman/history/web-v1/index.html',
            'games/01-ship/prototypes/web/index.html',
            'games/01-ship/prototypes/web/physics-matter-test.html',
            'games/01-ship/prototypes/web/chain-throw-test.html',
            'games/01-ship/prototypes/web/physics-three-test.html',
            'games/03-anchor-drift/prototypes/web/perspective.html',
            'games/03-anchor-drift/prototypes/web/three-anchor.html',
        ):
            with self.subTest(page=route):
                self.fetch(route)

    def test_godot_experiments_are_preserved(self):
        for relative in (
            'games/03-anchor-drift/prototypes/anchor-runner-godot',
            'games/03-anchor-drift/prototypes/anchor-river-3d',
            'games/03-anchor-drift/prototypes/anchor-river-whitebox-4.3',
        ):
            with self.subTest(project=relative):
                self.assertTrue((ROOT / relative / 'project.godot').is_file())

    def test_added_asset_provenance_points_to_existing_identical_files(self):
        manifest = json.loads((ROOT / 'docs/source-manifest.json').read_text())
        for asset in manifest['added_assets']:
            source, target = ROOT / asset['source'], ROOT / asset['destination']
            with self.subTest(asset=asset['destination']):
                self.assertTrue(source.is_file(), asset['source'])
                self.assertTrue(target.is_file(), asset['destination'])
                self.assertEqual(source.read_bytes(), target.read_bytes())

    def test_readme_links_and_images_resolve(self):
        for path in ROOT.rglob('README.md'):
            if '.git' in path.parts or '.godot' in path.parts:
                continue
            for link in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', path.read_text()):
                parts = urlsplit(link.strip('<>'))
                if parts.scheme or parts.netloc or not parts.path:
                    continue
                with self.subTest(document=str(path.relative_to(ROOT)), link=link):
                    self.assertTrue((path.parent / unquote(parts.path)).exists())


if __name__ == '__main__':
    unittest.main()
