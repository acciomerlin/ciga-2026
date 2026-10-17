"""Run the workspace locally: python3 tools/serve.py [--port 8080]."""
import argparse
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    handler = partial(Handler, directory=str(root))
    server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    print(f'CiGA: http://127.0.0.1:{args.port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
