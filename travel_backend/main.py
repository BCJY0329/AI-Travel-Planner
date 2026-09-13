"""
Entry point for the travel planner backend.
Run with: uvicorn main:app --reload
Then open http://127.0.0.1:8000/docs for interactive API docs.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import weather, places, flights, hotels, lemon

app = FastAPI(
    title="Travel Planner API",
    description="Backend for the AI-assisted trip planner (view-only data: no bookings/payments yet).",
    version="0.3.0",
)

# Flutter Web runs in the browser, so without CORS enabled every request
# from the frontend gets blocked before it even reaches these routes.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev-friendly default — tighten to your real domain(s) before shipping
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(weather.router)
app.include_router(places.router)
app.include_router(flights.router)
app.include_router(hotels.router)
app.include_router(lemon.router)


@app.get("/health")
async def health_check():
    return {"status": "ok"}