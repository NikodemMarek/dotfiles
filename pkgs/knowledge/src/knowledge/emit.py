"""Sending a submission to the event router (S4): `POST <router_url>/events`, answered with 202."""

import http.client
import time
from collections.abc import Sequence
from urllib.parse import urlsplit

from . import data, secrets
from .data import Obj
from .records import Record, origin_obj

EVENT_TYPE = "knowledge.submit"
DELAYS = (0.5, 1.5, 3.0)  # seconds to wait before each retry
TIMEOUT = 5.0  # seconds, per attempt
_ACCEPTED = 202
_REJECTED = 400  # the router will not accept this event however often it is sent
_DETAIL_BYTES = 512


class EmitError(Exception):
    """The router did not take the event. `permanent`: it never will, do not retry later."""

    def __init__(self, message: str, permanent: bool = False) -> None:
        super().__init__(message)
        self.permanent = permanent


def build_event(rec: Record) -> Obj:
    """The wire event of a record (flat apart from `origin`; what the router passes on to `knowledge receive`)."""
    return {
        "type": EVENT_TYPE,
        "id": rec.id,
        "title": rec.title,
        "body": rec.body,
        "kind": rec.kind,
        "scope": rec.scope,
        "evidence": rec.evidence,
        "origin": origin_obj(rec.origin),
    }


def hard_secret(rec: Record) -> str | None:
    """The kind of the first hard secret in the text fields of a record, origin included (never the secret itself), else None."""
    o = rec.origin
    for text in (rec.title, rec.body, rec.evidence, o.via, o.agent, o.cwd, o.event, o.session):
        if text is None:
            continue
        for finding in secrets.scan(text):
            if finding.severity == "hard":
                return finding.kind
    return None


def _target(url: str) -> tuple[bool, str, int | None, str]:
    """(https, host, port, path of /events) of a router URL."""
    try:
        parts = urlsplit(url)
        port = parts.port
    except ValueError as e:
        raise EmitError(f"bad router URL {url!r}: {e}", permanent=True) from e
    if parts.scheme not in ("http", "https") or not parts.hostname:
        raise EmitError(f"bad router URL {url!r}: expected http://host[:port]", permanent=True)
    return parts.scheme == "https", parts.hostname, port, parts.path.rstrip("/") + "/events"


def _once(url: str, payload: bytes, timeout: float) -> tuple[int, str]:
    """One POST: the status and the start of the answer."""
    https, host, port, path = _target(url)
    conn = (
        http.client.HTTPSConnection(host, port, timeout=timeout)
        if https
        else http.client.HTTPConnection(host, port, timeout=timeout)
    )
    try:
        conn.request("POST", path, body=payload, headers={"Content-Type": "application/json"})
        resp = conn.getresponse()
        detail = resp.read(_DETAIL_BYTES).decode("utf-8", "replace").strip()
        return resp.status, detail
    finally:
        conn.close()


def post(event: Obj, url: str, delays: Sequence[float] = DELAYS, timeout: float = TIMEOUT) -> None:
    """Deliver the event. 202 is done, 400 fails at once, anything else is retried after each of `delays`, then fails."""
    payload = data.dumps(event).encode("utf-8", "replace")
    last = ""
    for attempt in range(len(delays) + 1):
        if attempt:
            time.sleep(delays[attempt - 1])
        try:
            status, detail = _once(url, payload, timeout)
        except (OSError, http.client.HTTPException) as e:
            last = str(e) or type(e).__name__
            continue
        if status == _ACCEPTED:
            return
        if status == _REJECTED:
            raise EmitError(f"router answered 400: {detail}", permanent=True)
        last = f"router answered {status}: {detail}" if detail else f"router answered {status}"
    raise EmitError(last)
