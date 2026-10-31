"""
Small in-process cache so repeated page visits don't spend external API quota.

Only successful results are stored; errors always propagate and are retried on
the next request. Concurrent misses for the same key share one upstream call.
Entries live in this process only, so a backend restart (including uvicorn
--reload) starts empty.
"""
import asyncio
import copy
import time
from collections import OrderedDict
from typing import Any, Awaitable, Callable, Hashable


class TTLCache:
    def __init__(self, ttl_seconds: float, max_entries: int = 256):
        self.ttl = ttl_seconds
        self.max_entries = max_entries
        self._entries: "OrderedDict[Hashable, tuple[float, Any]]" = OrderedDict()
        self._pending: dict[Hashable, asyncio.Future] = {}

    async def get_or_fetch(self, key: Hashable, fetch: Callable[[], Awaitable[Any]]) -> Any:
        hit = self._entries.get(key)
        if hit is not None:
            if hit[0] > time.monotonic():
                self._entries.move_to_end(key)
                return copy.deepcopy(hit[1])
            del self._entries[key]

        task = self._pending.get(key)
        if task is None or task.get_loop() is not asyncio.get_running_loop():
            task = asyncio.ensure_future(fetch())
            self._pending[key] = task
            task.add_done_callback(lambda done, key=key: self._settle(key, done))
        # Shield: a caller that times out (e.g. itinerary context) must not
        # cancel the shared fetch for everyone else waiting on it.
        return copy.deepcopy(await asyncio.shield(task))

    def _settle(self, key: Hashable, task: asyncio.Future) -> None:
        if self._pending.get(key) is task:
            del self._pending[key]
        # exception() also marks the error as retrieved if nobody awaited it.
        if task.cancelled() or task.exception() is not None:
            return
        self._entries[key] = (time.monotonic() + self.ttl, task.result())
        self._entries.move_to_end(key)
        while len(self._entries) > self.max_entries:
            self._entries.popitem(last=False)

    def clear(self) -> None:
        self._entries.clear()
        self._pending.clear()


def normalize(text: str) -> str:
    """Cache key form of a free-text place name: 'Kyoto ' and 'kyoto' share an entry."""
    return " ".join(text.split()).casefold()
