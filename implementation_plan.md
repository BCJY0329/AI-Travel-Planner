# Redesign & Feature Expansion for Travel Planner Frontend (Flutter Web)

This plan outlines the complete revamp of the **AI Travel Planner** Flutter Web application, introducing a modern **lavender/periwinkle + white** aesthetic, adding dedicated viewing and search interfaces for **flights, hotels, and attractions**, refining **Lemon.ai**'s itinerary output to be clean and free of raw symbols (`##`), and updating error handling to display a friendly message and reloop to the start.

## User Review Required

> [!IMPORTANT]
> - **Theme Transformation**: The color palette will shift from standard amber/blue to an elegant **periwinkle & lavender** (`#6E7BF5`, `#7B66FF`, `#EDE9FE`, `#F8F7FD`) + crisp **white** (`#FFFFFF`) with subtle slate typography (`#1E1B4B`). Lemon.ai's cheerful yellow badge accent (`#F59E0B`) will be retained as an avatar brand accent.
> - **Error Handling Flow**: If an API error, timeout, or provider failure occurs, Lemon.ai will **not** display the backend terminal trace or API exception string. It will respond with: *"Sorry, I hit an error. Please try again!"* and immediately reset the flow to the beginning ("Where are you headed?").
> - **Itinerary Sanitization**: Any raw markdown symbols (`##`, `#`, `**`, `*`, markdown fences) will be stripped both at the prompt level (in backend) and sanitized in the frontend data layer, rendered through modern structured timeline cards.

---

## Proposed Changes

### 1. Design System & Theme (`lib/config/app_theme.dart`)
#### [NEW] [app_theme.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/config/app_theme.dart)
- Define the curated Lavender / Periwinkle palette:
  - `primary`: `#6E7BF5` / `#7B66FF`
  - `primaryLight`: `#EDE9FE`
  - `secondary`: `#8B80F9`
  - `surface`: `#FFFFFF`
  - `background`: `#F8F7FD`
  - `textPrimary`: `#1E1B4B`
  - `textSecondary`: `#6B7280`
  - `accentLemon`: `#FBBF24`
- Configure Google-style Material 3 `ThemeData` with custom card themes, elevated button styles, text field decorations, and subtle border radius.

---

### 2. Backend Services & Frontend API Integration
#### [NEW] [travel_api_service.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/services/travel_api_service.dart)
- Connect to backend endpoints:
  - `GET /flights/search?origin=...&destination=...&departure_date=...&adults=...`
  - `GET /hotels/search?city=...&radius_km=...`
  - `GET /places/attractions?city=...&radius_km=...`
- Implement fallback/mock curated results when an API key is missing or when backend raises an error, ensuring smooth interactive demo capability.

#### [NEW] [travel_models.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/models/travel_models.dart)
- Data models for:
  - `FlightOffer` (airline, flight number, origin, destination, departure/arrival time, duration, stops, price, currency).
  - `HotelItem` (name, address, lat, lon, rating, sample amenities).
  - `AttractionItem` (name, category, lat, lon, description).

---

### 3. Clean Itinerary & Data Sanitization
#### [MODIFY] [itinerary_models.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/models/itinerary_models.dart)
- Add string cleaner function `cleanAiText(String text)` that removes `##`, `#`, `**`, `*`, `__`, bullet dashes, and raw markdown tags.
- Sanitize `summary`, `activity`, `location`, and `notes` upon parsing from JSON.

#### [MODIFY] [itinerary_builder.py](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_backend/services/itinerary_builder.py)
- Update `SYSTEM_PROMPT` to explicitly instruct providers never to use `##`, `#`, asterisks `**`, or markdown symbols in JSON values.

---

### 4. Lemon.ai Chat & Error Handling
#### [MODIFY] [lemon_chat_controller.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/chat/lemon_chat_controller.dart)
- Update error handling:
  - Catch all exceptions (`LemonApiException`, timeouts, format errors, network errors).
  - Remove loading message.
  - Send message: *"Sorry, I hit an error. Please try again!"*
  - Automatically reloop to the start: call `_resetFlow()`, reset step to `ChatStep.destination`, and prompt: *"Where are you headed next?"*.
- Store the latest generated itinerary in a shared property `latestItinerary` so the main dashboard can showcase the visual itinerary.

#### [MODIFY] [chat_bubble.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/widgets/chat_bubble.dart)
- Restyle chat bubbles with periwinkle and soft lavender tones.
- Replace simple green box with a clean, modern itinerary preview card featuring Day pills, time badges, location chips, and note highlights.

#### [MODIFY] [lemon_chat_panel.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/widgets/lemon_chat_panel.dart)
- Restyle panel header with lavender/periwinkle gradient, clean input box, and periwinkle send button.

---

### 5. Main UI & Feature Views
#### [NEW] [flights_view.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/screens/views/flights_view.dart)
- Flight search bar (Origin IATA, Destination IATA, Departure Date, Passengers).
- Quick route chips (e.g. KUL -> NRT, SIN -> HND, JFK -> LHR, CDG -> FCO).
- Flight results list with airline badges, times, duration, stops indicator, price cards in periwinkle theme.

#### [NEW] [hotels_view.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/screens/views/hotels_view.dart)
- City search bar with radius selector (5km, 10km, 15km).
- Hotel cards with hotel name, address, rating stars, amenity badges, and view on map button.

#### [NEW] [attractions_view.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/screens/views/attractions_view.dart)
- City attractions search bar with category filters (sights, landmarks, culture, entertainment).
- Attraction cards with category chips, coordinate pins, and bookmark actions.

#### [NEW] [itinerary_view.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/screens/views/itinerary_view.dart)
- Full-page interactive visual itinerary viewer when an itinerary is generated:
  - Day selector tabs (Day 1, Day 2, Day 3).
  - Clean timeline with time chips, activity titles, location badges, and tip cards.
  - Trip overview banner (Destination, Dates, Budget, AI Provider).
  - Quick action to "Ask Lemon.ai to adjust" or "Export / Copy".

#### [MODIFY] [home_screen.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/screens/home_screen.dart)
- Replace blank placeholder with a high-end web layout:
  - Top Navigation Bar with brand logo, Periwinkle tabs ("Discover & Plan", "Flights", "Hotels", "Attractions", "Active Itinerary").
  - Hero banner with quick destination inspiration cards.
  - Floating Lemon.ai widget with animated badge and expandable assistant panel.
  - Responsive layout (supports desktop wide view and mobile compact view).

#### [MODIFY] [main.dart](file:///c:/Users/Acer/Documents/Coding%20Works/Works%20-%20Py/Work3%20-%20AI%20Travel%20Planner/travel_planner_frontend/lib/main.dart)
- Wire up the new lavender/periwinkle theme.

---

## Verification Plan

### Automated / Build Verification
- Run `flutter analyze` inside `travel_planner_frontend` to ensure 0 compile or lint errors.
- Test backend endpoints with python to confirm clean JSON response and no raw markdown.

### Manual / Browser Verification
- Open the web application in Chrome browser.
- Verify lavender/periwinkle + white aesthetic across all views.
- Test flight search (e.g. KUL to NRT).
- Test hotel search (e.g. Paris).
- Test attractions search (e.g. Tokyo, Paris).
- Chat with Lemon.ai to generate an itinerary:
  - Verify that the generated itinerary contains NO `##` or raw markdown symbols.
  - Verify the itinerary is neatly rendered in both the chat bubble and the Itinerary viewer.
- Trigger an error (e.g. select an invalid provider or simulate network error):
  - Verify Lemon.ai does NOT display terminal or backend tracebacks.
  - Verify Lemon.ai states: *"Sorry, I hit an error. Please try again!"* and resets cleanly back to step 1.
