"""
Run this FIRST, before touching the Flutter app at all.

It tests the Alfatah scraper directly — no Flask, no phone, nothing else
in the way. If this doesn't print real prices, nothing downstream will
work either, so this is the fastest way to find out if scraping works
from YOUR internet connection.

Usage:
    cd backend
    pip install -r requirements.txt
    python test_scraper.py

Once every line below prints a real price (not "None"), you're ready to
run app.py and try it from the phone. Only then should you open
scraper/store_configs.json and flip "naheed" and/or "metro" to
"enabled": true, one at a time, and re-run this file to check them too
(add them to TESTS below first).
"""

from scraper.alfatah_scraper import AlfatahScraper

# (product name as Alfatah would see it, unit) — a handful of real items
# from products.json, on purpose spanning different units (L, kg, g).
TESTS = [
    ("Milk", "1 L"),
    ("Rice", "1 kg"),
    ("Sugar", "1 kg"),
    ("Cooking Oil", "1 L"),
    ("Tea", "250 g"),
]

if __name__ == "__main__":
    scraper = AlfatahScraper()
    print(f"Testing {scraper.store_name}...\n")

    ok, failed = 0, 0
    for name, unit in TESTS:
        query = f"{name} {unit}"
        price = scraper.fetch_price(query)
        if price is None:
            print(f"  [NO PRICE]  {query}")
            failed += 1
        else:
            print(f"  [OK] {query:<20} -> Rs. {price}")
            ok += 1

    print(f"\n{ok} worked, {failed} failed.")
    if failed and not ok:
        print(
            "\nEverything failed — likely causes:\n"
            "  1. No internet on this machine right now\n"
            "  2. Alfatah changed their category URLs (edit CATEGORY_URLS "
            "in alfatah_scraper.py — open one of those pages in your "
            "browser and check the URL still matches)\n"
            "  3. Alfatah changed their page structure (the 'var meta = "
            "{...}' block this scraper looks for may have moved — open "
            "a category page, view source, and search for 'var meta')"
        )
    elif failed:
        print(
            "\nSome items failed — that's normal if Alfatah is simply out "
            "of stock on that size, or doesn't carry that exact product. "
            "As long as most items work, the scraper itself is fine."
        )
    else:
        print(
            "\nAll good — Alfatah scraping works from your connection. "
            "Now run: python app.py, then try Fetch Prices from the phone "
            "app (make sure the phone is on the same Wi-Fi as this PC)."
        )
