"""Places from photos and links (DECISIONS 073): POST /lemon/media."""
from typing import List, Literal, Optional
from pydantic import BaseModel, Field

MAX_IMAGES = 3            # Groq's vision model takes up to 3 images per request
MAX_LINKS = 2
MAX_IMAGE_BYTES = 4 * 1024 * 1024
# Base64 is 4 characters per 3 bytes.
_MAX_BASE64 = (MAX_IMAGE_BYTES * 4) // 3 + 8


class MediaImage(BaseModel):
    mime: Literal['image/jpeg', 'image/png', 'image/webp']
    data: str = Field(..., min_length=8, max_length=_MAX_BASE64, description="Base64 image bytes (no data: prefix)")


class MediaRequest(BaseModel):
    """Photos and/or links to look for places in. Images are read in memory
    only and never stored."""
    images: List[MediaImage] = Field(default_factory=list, max_length=MAX_IMAGES)
    links: List[str] = Field(default_factory=list, max_length=MAX_LINKS)
    destination: Optional[str] = Field(None, max_length=120, description="The trip's destination, if known")


class MediaCandidate(BaseModel):
    name: str
    city: Optional[str] = None
    country: Optional[str] = None
    confidence: Literal['high', 'maybe'] = 'maybe'
    evidence: str = ""                      # what the model saw ("sign reads ...", "caption: ...")
    source: Literal['photo', 'link'] = 'photo'
    # Map check: verified (Geoapify found it), not_found, or unchecked (the lookup failed).
    status: Literal['verified', 'not_found', 'unchecked'] = 'unchecked'
    place_id: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    matched_name: Optional[str] = None      # the map's own name, when it differs
    in_destination: Optional[bool] = None   # None when there is no destination to compare with
    distance_km: Optional[float] = None     # from the destination's centre


MEDIA_STATUSES = ('ok', 'nothing_found', 'needs_screenshot', 'busy', 'unavailable')


class MediaResponse(BaseModel):
    """status: 'ok' (candidates found), 'nothing_found', 'needs_screenshot'
    (a link that can't be read: Instagram/Facebook, or no usable preview),
    'busy' (the image model is rate limited: try again in a minute) or
    'unavailable' (a service failed). Never an HTTP error."""
    status: Literal['ok', 'nothing_found', 'needs_screenshot', 'busy', 'unavailable']
    reply: str
    candidates: List[MediaCandidate] = Field(default_factory=list)
    # With no destination yet: the city most candidates are in ("Kyoto, Japan").
    suggested_destination: Optional[str] = None
