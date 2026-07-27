"""
Pricing backend for the Grocery Price List app.

Endpoints:
  GET /match?q=<text>
      Matches free-text (any language/spelling) to a canonical product.
      Returns the product's valid units so the app can show the right
      dropdown. Returns suggestions if nothing confidently matches.

  GET /prices?product=<canonicalName>&unit=<unit>
      Returns the price for that exact product+unit from every store that
      has it, plus an approximate average — this is the "check all stores"
      comparison.

  GET /health

Run locally:
    pip install -r requirements.txt
    python app.py
"""

import json
from pathlib import Path
from flask import Flask, request, jsonify

from catalog.matcher import match_product, suggest_products, load_catalog
from scraper.generic_json_scraper import load_enabled_scrapers

app = Flask(__name__)

PRICES_FILE = Path(__file__).parent / "prices.json"


def load_price_db() -> dict:
    if PRICES_FILE.exists():
        with open(PRICES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


@app.route("/match", methods=["GET"])
def match():
    query = request.args.get("q", "")
    if not query.strip():
        return jsonify({"matched": False, "suggestions": []})

    result = match_product(query)
    if result:
        return jsonify({"matched": True, **result})

    suggestions = suggest_products(query)
    return jsonify({"matched": False, "suggestions": suggestions})


@app.route("/prices", methods=["GET"])
def get_prices():
    product_name = request.args.get("product", "")
    unit = request.args.get("unit", "")

    if not product_name or not unit:
        return jsonify({"error": "product and unit query params are required"}), 400

    db = load_price_db()
    store_prices = db.get(product_name, {})

    results = []
    for store, units in store_prices.items():
        if unit in units:
            results.append({"store": store, "unitPrice": units[unit]})

    # Fall back to live scrapers for stores that don't have this item cached
    scrapers = load_enabled_scrapers()
    known_stores = {r["store"] for r in results}
    for scraper in scrapers:
        if scraper.store_name in known_stores:
            continue
        scraped_price = scraper.fetch_price(f"{product_name} {unit}")
        if scraped_price is not None:
            results.append({"store": f"{scraper.store_name} (live)", "unitPrice": scraped_price})

    approx_average = None
    if results:
        approx_average = round(sum(r["unitPrice"] for r in results) / len(results), 2)

    return jsonify({
        "product": product_name,
        "unit": unit,
        "storePrices": results,
        "approxAverage": approx_average,
        "found": len(results) > 0,
    })


@app.route("/catalog", methods=["GET"])
def get_catalog():
    """Lets the app list all known products (e.g. for browsing/autocomplete)."""
    catalog = load_catalog()
    return jsonify({
        "products": [
            {
                "productKey": key,
                "canonicalName": p["canonical_name"],
                "units": p["units"],
                "defaultUnit": p["default_unit"],
            }
            for key, p in catalog.items()
        ]
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "liveScrapersEnabled": len(load_enabled_scrapers())})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
