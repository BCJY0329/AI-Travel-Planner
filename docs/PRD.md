# Product requirements

## Context

VoyageAI is a travel-planning prototype with Lemon.ai as its conversational assistant. Reconstructed from the working tree on 2026-10-08, this document describes observed scope and proposed acceptance criteria, not a previously approved roadmap.

## User and goal

Help a traveler explore a destination and assemble a day-by-day itinerary from destination, dates, party size, budget level, and interests.

## Current scope

- Flutter includes Discover, Flights, Hotels, Attractions, and Itinerary views.
- Lemon gathers trip details, exposes date prompts and confirmation, and requests an itinerary when ready.
- FastAPI exposes travel lookups, chat extraction, and itinerary generation.
- Real-provider generation and local mocks coexist; the frontend's `auto` selection is currently incompatible with the backend factory.
- Trip/chat state is held in memory; no persistence or user-account implementation was found in the inspected application flow.

## Intended journey

1. Open Lemon and provide destination and dates.
2. Supply travelers, budget, and interests, or express no specific interests.
3. Confirm the trip details.
4. Generate and view an itinerary; optionally start another trip.
5. Explore flight, hotel, and attraction views independently.

This is the intended journey; the provider mismatch currently blocks normal frontend chat.

## Proposed acceptance criteria

- The frontend's provider works with both Lemon endpoints in isolated tests.
- Intake retains all fields and requires confirmation before generation.
- Invalid dates, reversed ranges, and out-of-range travelers receive actionable validation.
- Demo results and unavailable hotel prices are clearly identified.
- Failures offer recovery without silently discarding user input.
- Tests cover chat progression, provider fallback, and itinerary rendering.

These are recommendations, not authorization to change code. See `TASKS.md` for gaps.

## Non-goals

Booking, payments, guaranteed live pricing, production authentication, and saved-trip synchronization are outside implemented scope. Hotel prices, ratings, and amenities are unavailable and are not fabricated by the frontend.

## Constraints and open questions

External data depends on credentials and availability. Current weather is a short-range forecast, not a forecast for arbitrary future trip dates. Deployment targets, data retention, supported locales, accessibility targets, and usage/cost limits need product decisions.
