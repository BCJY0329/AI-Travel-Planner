from typing import List, Optional
from pydantic import BaseModel


class PlacePhoto(BaseModel):
    id: int
    image_url: str  # path on this backend, e.g. "/photos/image/123"; prefix the API base URL
    page_url: str  # the photo's Pixabay page
    photographer: str
    photographer_url: str
    tags: str = ""  # Pixabay's comma-separated tags, usable as alt text


class PlacePhotosResponse(BaseModel):
    place: str  # the geocoded place name
    country_code: Optional[str] = None
    country: Optional[str] = None  # None when the code isn't in services/countries.py
    source: str = "Pixabay"
    photos: List[PlacePhoto]  # up to 3; may be empty


class FeaturedPhotosResponse(BaseModel):
    source: str = "Pixabay"
    photos: List[PlacePhoto]  # up to 10; may be empty
