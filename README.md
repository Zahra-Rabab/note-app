# Grocery Price List (Flutter)

A shopping list app supporting multiple named lists, multilingual/fuzzy
item matching, per-product units, and approximate multi-store pricing —
with prices fetched from a small backend you run.

## Recent fixes (from real device testing)

- **Units are now optional.** When an item matches the catalog, a checkbox
  lets you skip picking a unit — useful if you just want a plain notepad-
  style list. Items without a unit skip auto price-fetch and use manual
  pricing instead. (Also fixed a real bug here: the "Add" button was
  ignoring this checkbox and could silently attach a stale unit anyway —
  now fixed.)
- **Edit/Delete are now explicit buttons** (⋮ menu on each item), not just
  a swipe gesture — swipe-to-delete still works too, as a shortcut.
- **Checkbox vs. strikethrough**: tapping the checkbox on the left marks an
  item "done" (strikethrough) — this is separate from price entry. If an
  item shows a line through its name unexpectedly, the checkbox was tapped
  by accident; tap it again to clear it.
- **`python app.py` must be run from inside `/backend`**, not the project
  root — `cd backend` first, then `python app.py`.

## Status — what's actually verified vs. what needs your test run

- ✅ **Backend (`/backend`)** — actually run and tested end-to-end,
  including: exact/fuzzy/multilingual matching, unit resolution, and
  multi-store price averaging. Two real bugs were caught and fixed during
  testing (a price-parsing bug, and a false-positive substring match where
  "completely" matched the "tel" alias for Cooking Oil — both fixed and
  re-verified with regression tests).
- ✅ **Dart code (`/lib`)** — every file reviewed, every cross-file
  reference (constructor params, callback signatures, JSON keys returned
  by the backend vs. parsed by the app) checked by hand for consistency.
- ⚠️ **Not yet verified**: an actual `flutter run`. No Flutter SDK is
  available in the environment that built this, so I could not compile it
  myself — this remains the one real unknown. Send me any build errors.

## What's included

- **`/lib`** — the Flutter app:
  - **Multiple lists**: create, open, rename-ready, delete named lists
    from a home screen (`lists_screen.dart`)
  - **Smart item matching**: type a name in any language/spelling —
    the app calls the backend's `/match` endpoint as you type and shows
    the matched product with a green checkmark, or "did you mean...?"
    suggestions
  - **Unit + quantity**: once matched, a dropdown shows that product's
    valid units (e.g. Milk → 250 mL/500 mL/1 L/2 L), plus a +/- quantity
    stepper
  - **Multi-store approx pricing**: "Fetch Prices" checks every store that
    has that product+unit and shows the average, noting how many stores
    were compared
  - Edit (tap name), delete (swipe, with confirmation), clear list,
    manual price fallback, local persistence (sqflite)
- **`/backend`** — Flask server:
  - `catalog/products.json` — the product catalog: canonical names +
    aliases (English/Urdu/Roman Urdu/misspellings) + valid units
  - `catalog/matcher.py` — the matching engine (see below)
  - `prices.json` — manual price database, now structured as
    product → store → unit → price
  - `scraper/` — pluggable live-scraping system (unchanged from before,
    still empty until you configure a real store)
- **`/test`** — a basic smoke test

## How the matching actually works (as requested — the "why")

1. **Normalize** your input: lowercase, trim, collapse whitespace.
2. **Exact alias match** — if what you typed exactly equals a known alias
   (in any language), instant 100%-confidence match.
3. **Word-boundary match** — checks if a known alias appears as a whole
   word/phrase in your input (e.g. "Milk 1L" matches the "milk" alias).
   This is deliberately *not* raw substring matching — that caused a real
   bug during testing ("completely" contains "tel", which falsely matched
   the "tel" alias for Cooking Oil). Word boundaries fixed it.
4. **Fuzzy match** — edit-distance comparison (Python's `difflib`) against
   every known alias, for typos ("mlik" → Milk, confidence 0.75). Only
   accepted above a 0.72 confidence threshold, so it doesn't guess wildly.
5. If nothing crosses the threshold, you get 2-3 closest suggestions
   instead of a wrong guess.

**Honest limitation**: fuzzy matching (step 4) is strong for English/Roman
Urdu because character-level edit distance is a decent proxy for "typo
distance" in Latin script. It's weaker for Urdu script — a single Urdu
character can represent what took several Latin characters, so typo
patterns behave differently. Exact and word-boundary matching (steps 2-3)
work fine for Urdu; just make sure the exact Urdu spelling is in the
aliases list.

**Adding a new product or synonym**: edit `catalog/products.json` — no
code changes needed. Same for adding a new unit.

## First-time setup

```bash
flutter create .
flutter pub get
flutter run
```
`flutter create .` safely adds the platform folders (`android/`, etc.)
around your existing code without touching it.

## Running the backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```
Try it:
```bash
curl "http://localhost:5000/match?q=دودھ"
curl "http://localhost:5000/prices?product=Milk&unit=1%20L"
curl "http://localhost:5000/catalog"
```

The app is preconfigured to reach the backend at `http://10.0.2.2:5000`
(Android emulator's alias for your PC's localhost). On a real phone,
change `baseUrl` in `lib/services/api_service.dart` to your PC's LAN IP,
and add `android:usesCleartextTraffic="true"` to
`android/app/src/main/AndroidManifest.xml` (see troubleshooting notes
from our chat if `flutter run` shows install/network errors).

## Adding real store prices (scraping)

Unchanged from before — see `backend/scraper/HOW_TO_FIND_APIS.md` for the
step-by-step Network-tab guide. Once you find a store's API, fill in
`backend/scraper/store_configs.json` and set `"enabled": true`.

## Using the app

1. From **My Lists**, tap **+** to create a list, or tap an existing one.
2. Inside a list, tap **+** and start typing an item — in English, Roman
   Urdu, or Urdu script. Pick the matched unit, adjust quantity, Add.
3. Tap **Fetch Prices** — checks all known stores for each item and shows
   the approximate average.
4. Anything unmatched: tap its price to set one manually.
5. Tap an item's name to edit it; swipe left to remove it; use the
   top-right icon to clear the whole list.
