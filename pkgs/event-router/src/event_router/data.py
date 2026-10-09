"""Typed boundary for untyped data: parsing and checked field access."""

import json
import sys
from typing import cast

type Json = None | bool | int | float | str | list[Json] | dict[str, Json]
type Obj = dict[str, Json]


class ParseError(Exception):
    pass


def loads(data: str | bytes) -> Json:
    try:
        return cast(Json, json.loads(data))
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        raise ParseError(f"invalid json: {e}") from e


def dumps(value: Json) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def as_obj(value: Json, what: str = "value") -> Obj:
    if isinstance(value, dict):
        return value
    raise ParseError(f"{what}: expected object, got {type(value).__name__}")


def get_str(o: Obj, key: str) -> str:
    v = o.get(key)
    if isinstance(v, str):
        return v
    raise ParseError(f"{key}: expected string, got {type(v).__name__}")


def read_stdin() -> bytes:
    """Piped stdin, or b"" for a terminal (sys.stdin is typed as possibly Any)."""
    if sys.stdin is None or sys.stdin.isatty():
        return b""
    data: bytes = sys.stdin.buffer.read()
    return data
