"""A local stand-in for the event router: answers POST /events from a script and records what it was sent."""

import json
import threading
from collections.abc import Iterator
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class FakeRouter:
    def __init__(self, statuses: list[int]) -> None:
        self.statuses = statuses  # one answer per request, the last one repeats
        self.requests: list[tuple[str, str]] = []  # (path, raw body)
        self.url = ""

    @property
    def events(self) -> list[dict]:
        return [json.loads(body) for _, body in self.requests]

    def next_status(self) -> int:
        n = len(self.requests)
        return self.statuses[min(n, len(self.statuses) - 1)]


@contextmanager
def serve(*statuses: int) -> Iterator[FakeRouter]:
    """Answer the 1st request with the 1st status, and so on; with no statuses always 202."""
    router = FakeRouter(list(statuses) or [202])

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:
            length = int(self.headers.get("Content-Length") or "0")
            body = self.rfile.read(length).decode()
            status = router.next_status()
            router.requests.append((self.path, body))
            reply = b"answer\n"
            self.send_response(status)
            self.send_header("Content-Length", str(len(reply)))
            self.end_headers()
            self.wfile.write(reply)

        def log_message(self, format: str, *args: object) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    router.url = f"http://127.0.0.1:{server.server_address[1]}"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield router
    finally:
        server.shutdown()
        server.server_close()
        thread.join(5)


def closed_port_url() -> str:
    """A URL nothing listens on (the port was free a moment ago)."""
    server = ThreadingHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler)
    port = server.server_address[1]
    server.server_close()
    return f"http://127.0.0.1:{port}"
