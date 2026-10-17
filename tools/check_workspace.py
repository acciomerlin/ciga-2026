"""Check source size, static asset references and JS syntax without dependencies."""
import json
import re
import subprocess
import shutil
from pathlib import Path
from urllib.parse import urlsplit, unquote
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[1]

def source_files():
    output = subprocess.check_output(['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=ROOT)
    return sorted({ROOT / path.decode() for path in output.split(b'\0') if path})

class Assets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs = []
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('src', 'href', 'poster') and value:
                self.refs.append(value)

def main():
    files = source_files()
    problems = []
    optional_build_refs = []
    node = shutil.which('node')
    for path in files:
        relative = path.relative_to(ROOT)
        if path.stat().st_size >= 100 * 1024 * 1024:
            problems.append(f'File exceeds GitHub limit: {relative}')
        if path.suffix.lower() in ('.pdf', '.pem', '.key', '.p12', '.pfx', '.ttc', '.wasm', '.pck', '.zip'):
            problems.append(f'Unexpected source file: {relative}')
        if path.suffix == '.js' and 'vendor' not in path.parts and node:
            result = subprocess.run([node, '--check', str(path)], capture_output=True, text=True)
            if result.returncode:
                problems.append(f'JavaScript syntax error: {relative}: {result.stderr}')
        if path.suffix not in ('.html', '.css', '.gd', '.tscn', '.tres', '.godot'):
            continue
        text = path.read_text(errors='replace')
        refs = []
        if path.suffix == '.html':
            parser = Assets()
            parser.feed(text)
            refs.extend(parser.refs)
        if path.suffix in ('.css', '.html'):
            refs.extend(re.findall(r'url\(\s*[\'"]?([^\)\'"\s]+)', text))
        refs.extend(re.findall(r'"(res://[^"\n]+)"', text))
        for value in refs:
            if any(mark in value for mark in ('${', '{{', '*')):
                continue
            if value.startswith('res://'):
                project = next((p for p in path.parents if (p / 'project.godot').is_file()), None)
                if not project:
                    continue
                target = project / value.removeprefix('res://')
            else:
                parts = urlsplit(value)
                if parts.scheme or parts.netloc or not parts.path:
                    continue
                target = path.parent / unquote(parts.path)
            target = target.resolve()
            if not target.exists():
                try:
                    target_rel = target.relative_to(ROOT)
                except ValueError:
                    problems.append(f'Asset escapes workspace: {relative}: {value}')
                    continue
                if target_rel.parts[0] == 'dist':
                    optional_build_refs.append(str(target_rel))
                else:
                    problems.append(f'Missing asset: {relative}: {value}')
    print(json.dumps({'source_files': len(files), 'source_bytes': sum(p.stat().st_size for p in files),
                      'largest_source_file_bytes': max(p.stat().st_size for p in files),
                      'node_syntax_check': bool(node), 'unbuilt_optional_games': sorted(set(optional_build_refs)),
                      'problems': sorted(set(problems))}, ensure_ascii=False, indent=2))
    raise SystemExit(bool(problems))

if __name__ == '__main__':
    main()
