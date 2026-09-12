"""
Entry point for the travel planner backend.
Run with: uvicorn main:app --reload
Then open http://127.0.0.1:8000/docs for interactive API docs.
"""
from fastapi import FastAPI
from routers import weather, places, flights, hotels, lemon

app = FastAPI(
    title="Travel Planner API",
    description="Backend for the AI-assisted trip planner (view-only data: no bookings/payments yet).",
    version="0.2.0",
)

app.include_router(weather.router)
app.include_router(places.router)
app.include_router(flights.router)
app.include_router(hotels.router)
app.include_router(lemon.router)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
