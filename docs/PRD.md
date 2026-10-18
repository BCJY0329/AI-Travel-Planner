# Product requirements

## Context

LemonTrip (formerly VoyageAI) is a travel-planning prototype with Lemon.ai as its conversational assistant. Reconstructed from the working tree on 2026-10-08 and updated to current source on 2026-10-17, this document describes observed scope and proposed acceptance criteria, not a previously approved roadmap.

## User and goal

Help a traveler explore a destination and assemble a day-by-day itinerary from destination, dates, party size, budget level, and interests.

## Current scope

- Flutter includes Discover, Flights, Hotels, Attractions, and Itinerary views.
- Lemon interprets the destination through chat, then collects dates, travelers, budget, and interests through guided controls, shows an editable review, and generates an itinerary only after explicit confirmation.
- FastAPI exposes travel lookups, chat extraction, and windowed itinerary generation.
- Real-provider generation and local mocks coexist; the frontend's `auto` selection falls back across providers and labels demo output.
- Trip/chat state is held in memory; no persistence or user-account implementation was found in the inspected application flow.

## Intended journey

1. Open Lemon and name a destination.
2. Pick a date range (1–30 days), travelers, budget, and interests (or Surprise me).
3. Review and confirm the trip details.
4. Generate and view an itinerary; optionally start another trip.
5. Explore flight, hotel, and attraction views independently (search tabs do not yet follow the planned trip; KI-21).

## Proposed acceptance criteria

- The frontend's provider works with both Lemon endpoints in isolated tests.
- Intake retains all fields and requires confirmation before generation.
- Invalid dates, reversed ranges, and out-of-range travelers receive actionable validation.
- Demo results and unavailable hotel prices are clearly identified.
- Failures offer recovery without silently discarding user input.
- Tests cover chat progression, provider fallback, and itinerary rendering.

As of 2026-10-17, the implementation addresses these areas and offline tests cover much of them (see `TESTING.md` for exactly what ran); live-provider behavior and final visual acceptance remain unverified. These are recommendations, not authorization to change code. See `TASKS.md` for gaps.

## Non-goals

Booking, payments, guaranteed live pricing, production authentication, and saved-trip synchronization are outside implemented scope. Hotel prices, ratings, and amenities are unavailable and are not fabricated by the frontend.

## Constraints and open questions

External data depends on credentials and availability. Current weather is a short-range forecast, not a forecast for arbitrary future trip dates. Deployment targets, data retention, supported locales, accessibility targets, and usage/cost limits need product decisions.
