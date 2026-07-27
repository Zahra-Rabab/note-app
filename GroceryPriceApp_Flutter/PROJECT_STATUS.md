# Grocery Price List — Project Status

_Last updated: this conversation. Read this top to bottom if you're picking
this project back up, or handing it to another AI tool for help._

## The Goal

An Android app (Flutter/Dart) where you:
1. Build a shopping list (multiple named lists)
2. Type items in English, Urdu, or Roman Urdu — the app understands typos
   and different spellings and matches them to a known product
3. Pick a unit/size (Milk → 1L, Eggs → Dozen, etc.) — offered automatically
   once matched
4. Tap "Fetch Prices" — the app checks real Pakistani grocery store
   websites and shows an approximate average price and total bill

## The Architecture

```
GroceryPriceApp_Flutter/
├── lib/                    ← the Flutter app (what runs on your phone)
│   ├── main.dart               entry point, theme setup
│   ├── models/                 GroceryList, ShoppingItem
│   ├── providers/              app logic (lists, items, theme)
│   ├── screens/                Lists screen, list-detail screen, NEW: Settings screen
│   ├── services/                database (sqflite), API calls to backend
│   └── widgets/                Add/edit item dialog, item row
│
└── backend/                 ← Python/Flask server, runs on YOUR PC
    ├── app.py                  the server: /match, /prices, /catalog, /health
    ├── catalog/                 product dictionary + fuzzy/multilingual matcher
    ├── prices.json              manual fallback prices
    └── scraper/                 live price-fetching from real stores
        ├── alfatah_scraper.py       Alfatah — REAL, TESTED, WORKING
        ├── jsonld_scraper.py        Naheed/Metro — untested live, best-effort
        └── store_configs.json       turns each store on/off
```

**Critical thing to understand**: these are TWO separate programs.
- The **app** runs on your **phone**.
- The **backend** runs on your **PC** (`python app.py`).
- They talk to each other over your **home Wi-Fi** — both devices must be
  on the same network, and the PC must be running the backend, for
  fetching to work. This is a development-only setup; it's not "always on"
  the way a real deployed app would be (see "Not done yet" below).

## What's VERIFIED working right now (tested for real, not assumed)

- Backend server itself: starts cleanly, `/health` responds
- Product matching: typing "milk", "دودھ", "daal", "eggs" etc. correctly
  identifies the product and offers the right units automatically
- **Alfatah live scraping**: confirmed via direct `curl` test — Milk 1L
  returns real prices from 3 sources (Imtiaz manual: 320, Metro manual:
  315, **Alfatah live: 350**), averaging to Rs. 328.33
- A serious pricing bug was found and fixed: the scraper was initially
  returning a 12-bottle wholesale carton price (Rs. 4200) instead of a
  single bottle price — fixed by excluding multi-pack variants

## What's NOT yet confirmed

- **The phone app has never once successfully reached the backend.**
  Every fix applied so far (correct IP, Android internet permission,
  cleartext traffic setting) was necessary but hasn't been proven
  sufficient yet — the connection test from the phone itself hasn't
  succeeded.
- Naheed and Metro scrapers (added by a separate AI session) — code
  reviewed and looks sound, but never actually tested against the live
  internet.
- A full `flutter run` compile has happened successfully on your PC, but
  various features added since then haven't all been exercised on-device.

## The single blocking issue, right now

The phone cannot reach `http://<your-pc-ip>:5000`. Ruled out so far:
wrong IP (fixed), missing Android permissions (fixed), wrong Wi-Fi
(confirmed same network). **Leading unconfirmed suspect: Windows Firewall
silently blocking inbound connections from other devices on port 5000.**

### To fix it — do this now
1. Open the app → tap the gear icon (Settings, top-right of "My Lists")
2. Enter your PC's current IP (check with `ipconfig` on the PC first —
   it has changed multiple times already) as `http://<ip>:5000`
3. Tap **Test Connection**
4. **If it fails**: Windows Security → Firewall & network protection →
   Advanced settings → Inbound Rules → New Rule → Port → TCP → Specific
   port `5000` → Allow the connection → apply to Private network → name
   it "Flask Grocery Backend"
5. Retry Test Connection

Once Test Connection succeeds, fetching should work immediately — the
backend itself is already proven correct.

## Longer-term (not urgent, discussed but not built)

Right now this only works when your PC is on and both devices share
Wi-Fi. The real fix is deploying the backend to a free cloud host (Render,
Railway) or Firebase Cloud Functions, so it's reachable from anywhere,
anytime, without your PC needing to be on. Not done — deliberately
deferred until the local version works end-to-end first.

## A caution for whoever picks this up next

Multiple AI tools (this chat, a separate Claude session, and Gemini/AI
Studio) have all edited this project independently at different points.
At least one real conflict already happened (duplicate scraper configs).
**Before trusting any file's current state, check `git status` / `git
diff`** if git has been set up, or explicitly ask whichever AI tool
you're using to list exactly what it changed before proceeding.
