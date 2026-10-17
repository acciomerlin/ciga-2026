"""Build both Godot Web games; requires Godot 4.7 and matching Web templates."""
import argparse
import os
import shutil
import subprocess
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--game', choices=['all', 'anchorshackeshacke', 'help-ai-anchorman'], default='all')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    executable = shutil.which(args.godot)
    if not executable:
        parser.error('Godot not found. Set GODOT or pass --godot /path/to/Godot')
    games = ['anchorshackeshacke', 'help-ai-anchorman'] if args.game == 'all' else [args.game]
    for game in games:
        project = root / 'games' / game
        output = root / 'dist' / game / 'index.html'
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([executable, '--headless', '--editor', '--path', str(project), '--import'], check=True)
        subprocess.run([executable, '--headless', '--path', str(project),
                        '--export-release', 'Web', str(output)], check=True)
        if not output.is_file() or not output.with_suffix('.pck').is_file() or not output.with_suffix('.wasm').is_file():
            raise RuntimeError(f'Incomplete Web export: {game}')
        print(f'Exported: {output.relative_to(root)}', flush=True)

if __name__ == '__main__':
    main()
