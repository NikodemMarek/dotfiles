import re
from dataclasses import dataclass

from .data import Json, Obj, ParseError, as_obj, dumps, get_str

# types become handler file names, keep them filename-safe; dots namespace
# them by producer, e.g. "gitlab.note"
TYPE_RE = re.compile(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*")


@dataclass(frozen=True)
class Event:
    """A flat JSON object with a `type`; everything else is payload, passed through untouched."""

    type: str
    data: Obj

    @staticmethod
    def from_json(value: Json) -> "Event":
        o = as_obj(value, "event")
        type_ = get_str(o, "type")
        if not TYPE_RE.fullmatch(type_):
            raise ParseError(f"type: must match {TYPE_RE.pattern}, got {type_!r}")
        return Event(type_, o)

    def dumps(self) -> str:
        return dumps(self.data)

    def describe(self) -> str:
        return self.type
