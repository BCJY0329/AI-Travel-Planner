from typing import List, Optional
from pydantic import BaseModel


class Airport(BaseModel):
    iata_code: str
    name: str
    city_name: Optional[str] = None


class AirportsResponse(BaseModel):
    place: str
    airports: List[Airport]
