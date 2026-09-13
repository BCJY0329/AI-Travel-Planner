# Where to extract this

This zip contains a `lib/`, `assets/`, and `pubspec.yaml` meant to be merged
into a real Flutter project (they are not a full runnable project on their
own — a Flutter project also needs `android/`, `ios/`, `web/`, etc., which
`flutter create` generates for you).

## Steps

1. Create the Flutter project shell (if you haven't already), in your
   `Work3 - AI Travel Planner` folder, alongside `travel_backend/`:

   ```bash
   cd "Work3 - AI Travel Planner"
   flutter create travel_planner_frontend
   ```

2. Extract this zip's contents INTO that new `travel_planner_frontend/`
   folder, overwriting the default `lib/main.dart` and `pubspec.yaml` that
   `flutter create` generated. When done, the folder should look like:

   ```
   Work3 - AI Travel Planner/
   ├── travel_backend/            (already exists)
   └── travel_planner_frontend/
       ├── android/                (from flutter create)
       ├── ios/                    (from flutter create)
       ├── web/                    (from flutter create)
       ├── lib/                    <- from this zip (replaces default)
       ├── assets/
       │   └── images/
       │       └── lemon_avatar.png   <- put YOUR image here
       └── pubspec.yaml            <- from this zip (replaces default)
   ```

3. Add your avatar image at:

   ```
   travel_planner_frontend/assets/images/lemon_avatar.png
   ```

4. Install dependencies:

   ```bash
   cd travel_planner_frontend
   flutter pub get
   ```

5. Make sure the backend has CORS enabled (see the `main.py` update from
   our chat) and is running:

   ```bash
   cd ../travel_backend
   uvicorn main:app --reload
   ```

6. Run the frontend:

   ```bash
   cd ../travel_planner_frontend
   flutter run -d chrome        # Flutter Web
   # or, with an Android emulator running:
   flutter run
   ```

## Android internet permission

Open `android/app/src/main/AndroidManifest.xml` and make sure this line is
present inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
