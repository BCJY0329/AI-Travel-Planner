"""
Public preview data for a pasted link (DECISIONS 073): caption, author and
thumbnail, never the video or page body beyond its preview tags.

- TikTok and YouTube: their public oEmbed endpoints (no key).
- Instagram, Facebook and Threads: not read. Meta's oEmbed returns only embed
  HTML, and its terms limit that data to showing the embed, so Lemon asks for a
  screenshot instead.
- Other web pages: Open Graph / <title> / description tags from the first
  PAGE_LIMIT_BYTES of the page.
- Link shorteners are not followed (they hide where a link goes).

Every fetch is guarded: http(s) only, default ports, at most MAX_REDIRECTS
redirects, and each host must resolve only to public addresses, so a link
can't make the server open its own network (SSRF). The guard checks DNS before
connecting; a host that changes its answer between the check and the connect
(DNS rebinding) is not covered (KNOWN_ISSUES KI-38).

The HTTP client is imported lazily; tests replace `_fetch`.
"""
import asyncio
import html
import ipaddress
import logging
import re
import socket
from typing import Optional
from urllib.parse import quote, urljoin, urlsplit

logger = logging.getLogger("lemon_ai")

FETCH_TIMEOUT_SECONDS = 8.0
PAGE_LIMIT_BYTES = 1024 * 1024
IMAGE_LIMIT_BYTES = 4 * 1024 * 1024
MAX_REDIRECTS = 3
USER_AGENT = "LemonTrip/1.0 (link preview)"

URL_RE = re.compile(r"(?:https?://|www\.)[^\s<>\"']+", re.IGNORECASE)

_META = ("instagram.com", "instagr.am", "facebook.com", "fb.com", "fb.watch", "threads.net", "threads.com")
_TIKTOK = ("tiktok.com",)
_YOUTUBE = ("youtube.com", "youtu.be")
_SHORTENERS = ("bit.ly", "t.co", "tinyurl.com", "goo.gl", "ow.ly", "is.gd", "buff.ly", "rebrand.ly",
               "cutt.ly", "shorturl.at", "rb.gy", "tiny.cc", "lnkd.in")


class BlockedLink(Exception):
    """The link points somewhere the server must not fetch."""


def _clean(url: str) -> str:
    url = url.strip().rstrip(".,!?;:)]}'\"")
    return url if url.lower().startswith(("http://", "https://")) else "https://" + url


def _host(url: str) -> str:
    try:
        return (urlsplit(url).hostname or "").lower().rstrip(".")
    except ValueError:
        return ""


def _on(host: str, domains) -> bool:
    return any(host == d or host.endswith("." + d) for d in domains)


def classify(url: str) -> str:
    """'meta', 'tiktok', 'youtube', 'web', or 'unsupported' (shorteners, bad URLs)."""
    host = _host(_clean(url))
    if not host or "." not in host:
        return "unsupported"
    if _on(host, _META):
        return "meta"
    if _on(host, _TIKTOK):
        return "tiktok"
    if _on(host, _YOUTUBE):
        return "youtube"
    if _on(host, _SHORTENERS):
        return "unsupported"
    return "web"


def find_links(text: str) -> list:
    """Every link in `text`, cleaned, in order."""
    return [_clean(m.group(0)) for m in URL_RE.finditer(text or "")]


def strip_links(text: str) -> tuple:
    """(text without its readable links, those links, any other links left in).
    Readable means a kind Lemon can look at (or ask a screenshot for)."""
    readable, other = [], []
    def drop(match):
        url = _clean(match.group(0))
        (readable if classify(url) != "unsupported" else other).append(url)
        return " " if classify(url) != "unsupported" else match.group(0)
    left = URL_RE.sub(drop, text or "")
    return " ".join(left.split()), readable, other


# --- Guarded fetching ------------------------------------------------------------

async def _check_host(url: str) -> None:
    parts = urlsplit(url)
    if parts.scheme not in ("http", "https") or not parts.hostname:
        raise BlockedLink("scheme")
    if parts.port not in (None, 80, 443) or parts.username or parts.password:
        raise BlockedLink("port or credentials")
    host = parts.hostname
    try:
        literal = ipaddress.ip_address(host)
        addresses = [literal]
    except ValueError:
        try:
            infos = await asyncio.get_running_loop().getaddrinfo(host, None, type=socket.SOCK_STREAM)
        except socket.gaierror:
            raise BlockedLink("unresolvable")
        addresses = [ipaddress.ip_address(info[4][0].split("%")[0]) for info in infos]
    if not addresses or not all(a.is_global for a in addresses):
        raise BlockedLink("private address")


async def _fetch(url: str, limit: int, accept: str) -> tuple:
    """(final URL, content type, body bytes up to `limit`). Follows at most
    MAX_REDIRECTS redirects, checking each host. Raises on HTTP errors."""
    import httpx  # lazy: see module docstring
    async with httpx.AsyncClient(timeout=FETCH_TIMEOUT_SECONDS, follow_redirects=False,
                                 headers={"User-Agent": USER_AGENT, "Accept": accept}) as client:
        for _ in range(MAX_REDIRECTS + 1):
            await _check_host(url)
            async with client.stream("GET", url) as resp:
                if resp.is_redirect:
                    location = resp.headers.get("location")
                    if not location:
                        raise BlockedLink("redirect without location")
                    url = urljoin(url, location)
                    if classify(url) == "meta":
                        raise BlockedLink("redirect to meta")
                    continue
                resp.raise_for_status()
                body = bytearray()
                async for chunk in resp.aiter_bytes():
                    body.extend(chunk)
                    if len(body) >= limit:
                        break
                return url, resp.headers.get("content-type", ""), bytes(body[:limit])
    raise BlockedLink("too many redirects")


# --- Preview data ------------------------------------------------------------------

_META_TAG_RE = re.compile(r"<meta\s[^>]*>", re.IGNORECASE)
_ATTR_RE = re.compile(r"""([a-zA-Z:_-]+)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)""")
_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)


def _text(value, limit: int = 600) -> str:
    return " ".join(html.unescape(str(value or "")).split())[:limit]


def parse_open_graph(page: str, base_url: str) -> dict:
    """{title, description, author, image_url} from a page's head tags."""
    found = {}
    for tag in _META_TAG_RE.findall(page):
        attrs = {k.lower(): v.strip("\"'") for k, v in _ATTR_RE.findall(tag)}
        key = (attrs.get("property") or attrs.get("name") or "").lower()
        if key and "content" in attrs and key not in found:
            found[key] = attrs["content"]
    title = found.get("og:title") or found.get("twitter:title")
    if not title:
        match = _TITLE_RE.search(page)
        title = match.group(1) if match else ""
    image = found.get("og:image") or found.get("twitter:image") or ""
    return {
        "title": _text(title, 300),
        "description": _text(found.get("og:description") or found.get("description")
                             or found.get("twitter:description")),
        "author": _text(found.get("author") or found.get("og:site_name"), 120),
        "image_url": urljoin(base_url, _text(image, 1000)) if image else None,
    }


_GENERIC_TITLE_RE = re.compile(r"^\s*(tiktok|youtube)\b[\s\-–|:]*(make your day)?\s*$", re.IGNORECASE)


def _oembed_url(kind: str, url: str) -> str:
    if kind == "tiktok":
        return f"https://www.tiktok.com/oembed?url={quote(url, safe='')}"
    return f"https://www.youtube.com/oembed?format=json&url={quote(url, safe='')}"


async def read_preview(url: str) -> Optional[dict]:
    """{title, description, author, image_url} for a TikTok, YouTube or web
    link; None when there is nothing usable. Raises BlockedLink for links the
    server must not fetch, and network errors as they come."""
    import json
    url = _clean(url)
    kind = classify(url)
    if kind in ("meta", "unsupported"):
        raise BlockedLink(kind)
    if kind in ("tiktok", "youtube"):
        try:
            _, _, body = await _fetch(_oembed_url(kind, url), PAGE_LIMIT_BYTES, "application/json")
            data = json.loads(body.decode("utf-8", "replace"))
        except BlockedLink:
            raise
        except Exception as e:
            # Private, removed or region-blocked posts end here. Not worked around.
            logger.info("oEmbed unavailable for %s (%s)", kind, type(e).__name__)
            return None
        if not isinstance(data, dict):
            return None
        preview = {"title": _text(data.get("title"), 600), "description": "",
                   "author": _text(data.get("author_name"), 120),
                   "image_url": data.get("thumbnail_url") if isinstance(data.get("thumbnail_url"), str) else None}
        if preview["title"] or preview["image_url"]:
            return preview
        # TikTok's oEmbed returns only the embed iframe (live check
        # 2026-11-08), so its page's own Open Graph tags are read instead.
        try:
            final, ctype, body = await _fetch(url, PAGE_LIMIT_BYTES, "text/html")
        except BlockedLink:
            raise
        except Exception as e:
            logger.info("Page preview unavailable for %s (%s)", kind, type(e).__name__)
            return None
        if "html" not in ctype.lower():
            return None
        preview = parse_open_graph(body.decode("utf-8", "replace"), final)
        if _GENERIC_TITLE_RE.match(preview["title"]) and not preview["description"] and not preview["image_url"]:
            # Servers get TikTok's bot page ("TikTok - Make Your Day", live
            # check 2026-11-08): nothing to read, so Lemon asks for a screenshot.
            return None
    else:
        final, ctype, body = await _fetch(url, PAGE_LIMIT_BYTES, "text/html")
        if "html" not in ctype.lower():
            return None
        preview = parse_open_graph(body.decode("utf-8", "replace"), final)
    return preview if (preview["title"] or preview["description"] or preview["image_url"]) else None


async def fetch_image(url: str) -> Optional[tuple]:
    """(mime, bytes) for a preview thumbnail, or None when it isn't a usable image."""
    _, ctype, body = await _fetch(url, IMAGE_LIMIT_BYTES + 1, "image/*")
    mime = ctype.split(";")[0].strip().lower()
    if mime not in ("image/jpeg", "image/png", "image/webp") or len(body) > IMAGE_LIMIT_BYTES or not body:
        return None
    return mime, body
