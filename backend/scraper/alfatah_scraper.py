"""
Alfatah (alfatah.pk) scraper.

How it works — discovered through real testing, not guesswork:
Alfatah's site is Shopify-based. Each collection (category) page embeds a
Shopify analytics tracking script containing the FULL product list for that
category as plain JSON — no headless browser needed, just a regular HTTP
request. This is a much more reliable technique than CSS-selector scraping,
since it's structured data rather than parsed layout.

Three things this scraper does carefully, because getting them wrong gives
silently WRONG prices rather than an obvious error:
  1. Shopify prices are in the smallest currency subunit (paisa), so every
     price must be divided by 100.
  2. Product variant names include their size (e.g. "1 LTR" vs "1.5 LTR").
     Matching by fuzzy text alone isn't reliable enough to tell those
     apart, so this scraper parses actual quantities (e.g. "1.5 LTR" ->
     1500 mL) from both the requested unit and each candidate product, and
     matches on the closest real quantity — not just similar-looking text.
  3. Multi-pack/carton variants (e.g. "1 LTR (Pack of 12)") have the SAME
     per-unit quantity as a single bottle but a totally different price
     (the price of the whole pack). These are excluded before quantity
     matching even runs — otherwise a "1 L" request can silently return
     a 12-bottle carton price instead of a single bottle price.
"""

import re
import json
import time
from typing import Optional
import requests

from .base_scraper import StoreScraper

# Words that indicate a variant is a multi-pack/carton, not a single unit.
# Matching on quantity alone isn't enough — a "1 LTR (Pack of 12)" variant
# parses as 1000mL just like a single bottle, but its price is for all 12.
_MULTIPACK_INDICATORS = re.compile(
    r"\b(pack of|pkt of|carton|dozen|x\s?\d+|\d+\s?x|combo|bundle)\b",
    re.IGNORECASE,
)


def _is_multipack(variant_name: str) -> bool:
    return bool(_MULTIPACK_INDICATORS.search(variant_name))


# Maps our catalog's product keys to Alfatah's actual category URLs.
# Found by browsing alfatah.pk's own navigation menu — these are real,
# working category pages, not guesses. This covers the "Grocery Foods"
# section broadly, not literally every category the site has (Electronics,
# Makeup, etc. are irrelevant to a grocery list app, and Grocery Non-Food
# is left out for now — extend the same way if you want it).
CATEGORY_URLS = {
    "milk": "https://alfatah.pk/collections/milk-dairy-drinks",
    "rice": "https://alfatah.pk/collections/rice-price-in-pakistan",
    "sugar": "https://alfatah.pk/collections/sugar-price-in-pakistan",
    "flour": "https://alfatah.pk/collections/flour-price-in-pakistan",
    "cooking_oil": "https://alfatah.pk/collections/oil-ghee",
    "olive_oil": "https://alfatah.pk/collections/olive-oil-price-in-pakistan",
    "tea": "https://alfatah.pk/collections/tea-cofee",
    "eggs": "https://alfatah.pk/collections/bread-buns-eggs",
    "bread": "https://alfatah.pk/collections/bread-buns-eggs",
    "mash_dal": "https://alfatah.pk/collections/pulses",
    "pulses": "https://alfatah.pk/collections/pulses",
    "spices": "https://alfatah.pk/collections/spices",
    "cheese": "https://alfatah.pk/collections/cheese-cream",
    "butter": "https://alfatah.pk/collections/butter-margarine",
    "yogurt": "https://alfatah.pk/collections/yogurt-price-in-pakistan",
    "honey": "https://alfatah.pk/collections/honey-price-in-pakistan",
    "jam": "https://alfatah.pk/collections/jams-spreads",
    "sweetener": "https://alfatah.pk/collections/sweetner",
    "baking": "https://alfatah.pk/collections/baking-items-online-pakistan",
    "noodles": "https://alfatah.pk/collections/noodles-price-in-pakistan",
    "pasta": "https://alfatah.pk/collections/noodles-price-in-pakistan",
    "frozen_food": "https://alfatah.pk/collections/frozen-packaged-foods",
    "drinks": "https://alfatah.pk/collections/drinks-beverages",
    "nuts": "https://alfatah.pk/collections/nuts-dry-fruits",
    "ice_cream": "https://alfatah.pk/collections/ice-creams",
    "pickle": "https://alfatah.pk/collections/pickles-preserves",
    "tin_food": "https://alfatah.pk/collections/tin-food-price-in-pakistan",
    "sweets": "https://alfatah.pk/collections/sweets-chocolates",
    "biscuits": "https://alfatah.pk/collections/biscuit-cookies",
    "chips": "https://alfatah.pk/collections/chips-savories",
    "cereal": "https://alfatah.pk/collections/cereal-price-in-pakistan",
    "condiments": "https://alfatah.pk/collections/condiments-sauces",
}

# Cache fetched category pages for a short time so checking several items
# in the same category (e.g. two milk items) doesn't re-fetch the page
# each time — both faster and more polite to Alfatah's servers.
_CACHE_TTL_SECONDS = 300
_cache: dict[str, tuple[float, list]] = {}


def _extract_products_from_html(html: str) -> list:
    match = re.search(r"var meta = (\{.*?\});\s*\n\s*for \(var attr in meta\)", html, re.DOTALL)
    if not match:
        # Fall back to a looser match in case the trailing JS changes slightly
        match = re.search(r"var meta = (\{.*)", html)
        if not match:
            return []
        try:
            data, _ = json.JSONDecoder().raw_decode(match.group(1))
        except json.JSONDecodeError:
            return []
    else:
        try:
            data = json.loads(match.group(1))
        except json.JSONDecodeError:
            return []
    return data.get("products", [])


def _get_category_products(category_url: str) -> list:
    now = time.time()
    cached = _cache.get(category_url)
    if cached and (now - cached[0]) < _CACHE_TTL_SECONDS:
        return cached[1]

    # Without a browser-like User-Agent, Alfatah's server returns 403
    # Forbidden — confirmed by an actual failed request during testing.
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
    }
    response = requests.get(category_url, headers=headers, timeout=15)
    response.raise_for_status()
    products = _extract_products_from_html(response.text)
    _cache[category_url] = (now, products)
    return products


def _parse_quantity(text: str) -> Optional[tuple]:
    """(amount, normalized_unit) — e.g. '1.5 LTR' -> (1500, 'ml')."""
    text = text.upper()
    match = re.search(r"(\d+\.?\d*)\s*(LTR|L|ML|KG|G|GM)\b", text)
    if not match:
        return None
    amount = float(match.group(1))
    unit = match.group(2)
    if unit in ("LTR", "L"):
        return (amount * 1000, "ml")
    if unit == "ML":
        return (amount, "ml")
    if unit == "KG":
        return (amount * 1000, "g")
    if unit in ("G", "GM"):
        return (amount, "g")
    return None


class AlfatahScraper(StoreScraper):
    store_name = "Alfatah"

    def fetch_price(self, item_name_and_unit: str) -> Optional[float]:
        # app.py calls this with something like "Milk 1 L"
        category_url = None
        for key, url in CATEGORY_URLS.items():
            if key.replace("_", " ") in item_name_and_unit.lower():
                category_url = url
                break
        if category_url is None:
            return None

        try:
            products = _get_category_products(category_url)
        except Exception as e:
            print(f"[Alfatah] request failed: {e}")
            return None

        target_qty = _parse_quantity(item_name_and_unit)
        if target_qty is None:
            return None

        best_price = None
        best_diff = None
        for product in products:
            for variant in product.get("variants", []):
                name = variant.get("name", "")

                # Skip multi-pack/carton variants — same per-unit quantity
                # as a single item, but priced for the whole pack. Without
                # this check, a "1 L" request could silently match a
                # "1 LTR (Pack of 12)" variant and return the carton price.
                if _is_multipack(name):
                    continue

                candidate_qty = _parse_quantity(name)
                if candidate_qty is None or candidate_qty[1] != target_qty[1]:
                    continue
                diff = abs(candidate_qty[0] - target_qty[0])
                if best_diff is None or diff < best_diff:
                    best_diff = diff
                    best_price = variant["price"] / 100  # Shopify stores paisa

        # Only accept a genuinely close quantity match (within 5%), not just
        # "closest of whatever was available" — e.g. don't silently return a
        # 5kg price when 1kg was requested just because nothing else matched.
        if best_price is not None and best_diff <= target_qty[0] * 0.05:
            return best_price
        return None