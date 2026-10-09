"""HTTP inbox: `POST /events` with a JSON event, `GET /health`."""

import logging
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .data import ParseError, loads
from .event import Event
from .handlers import Dispatcher

log = logging.getLogger(__name__)

MAX_BODY = 1 << 20
REAP_INTERVAL = 5.0


def _handler(dispatcher: Dispatcher) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def _reply(self, code: int, msg: str) -> None:
            body = (msg + "\n").encode()
            self.send_response(code)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path == "/health":
                self._reply(200, "ok")
            else:
                self._reply(404, "not found")

        def do_POST(self) -> None:
            if self.path != "/events":
                self._reply(404, "not found")
                return
            try:
                length = int(self.headers.get("Content-Length") or "0")
            except ValueError:
                length = -1
            if not 0 < length <= MAX_BODY:
                self._reply(400, f"Content-Length must be 1..{MAX_BODY}")
                return
            try:
                event = Event.from_json(loads(self.rfile.read(length)))
            except ParseError as e:
                self._reply(400, str(e))
                return
            if dispatcher.dispatch(event):
                self._reply(202, "accepted")
            else:
                self._reply(500, f"no runnable handler for {event.describe()}")

        def log_message(self, format: str, *args: object) -> None:
            # access log is noise; dispatches are logged by the Dispatcher
            pass

    return Handler


def _reaper(dispatcher: Dispatcher) -> None:
    while True:
        time.sleep(REAP_INTERVAL)
        dispatcher.reap()


def serve(port: int, dispatcher: Dispatcher) -> None:
    server = ThreadingHTTPServer(("127.0.0.1", port), _handler(dispatcher))
    threading.Thread(target=_reaper, args=(dispatcher,), daemon=True).start()
    log.info("listening on 127.0.0.1:%d", port)
    try:
        server.serve_forever()
    finally:
        server.server_close()
