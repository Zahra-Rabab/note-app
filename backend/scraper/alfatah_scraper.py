"""
Alfatah (alfatah.pk) scraper.

How it works — discovered through real testing, not guesswork:
Alfatah's site is Shopify-based. Each collection (category) page embeds a
Shopify analytics tracking script containing the FULL product list for that
category as plain JSON — no headless browser needed, just a regular HTTP
request. This is a much more reliable technique than CSS-selector scraping,
since it's structured data rather than parsed layout.

Two things this scraper does carefully, because getting them wrong gives
silently WRONG prices rather than an obvious error:
  1. Shopify prices are in the smallest currency subunit (paisa), so every
     price must be divided by 100.
  2. Product variant names include their size (e.g. "1 LTR" vs "1.5 LTR").
     Matching by fuzzy text alone isn't reliable enough to tell those
     apart, so this scraper parses actual quantities (e.g. "1.5 LTR" ->
     1500 mL) from both the requested unit and each candidate product, and
     matches on the closest real quantity — not just similar-looking text.
"""

import re
import json
import time
from typing import Optional
import requests

from .base_scraper import StoreScraper

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
    """
    (amount, normalized_unit) — e.g. '1.5 LTR' -> (1500, 'ml').

    Also handles count-based units (Dozen, Pack of N, Tray, Single) for
    products like Eggs, which don't have a weight/volume at all. This was
    missing originally — the parser only understood L/mL/kg/g, so any
    count-based product (Eggs: Single/Pack of 6/Dozen/Tray) silently failed
    to match anything on Alfatah, even though the category page loaded fine.

    Honest caveat: this uses common, general patterns (PCS, PACK OF, X N,
    DOZEN) since I don't have a real sample of Alfatah's actual egg listing
    to test against (unlike Milk, where we had real data). Treat this as a
    reasonable first attempt that may need adjusting once you see real
    output — same as everything else here, verify with real testing.
    """
    text = text.upper()

    weight_match = re.search(r"(\d+\.?\d*)\s*(LTR|L|ML|KG|G|GM)\b", text)
    if weight_match:
        amount = float(weight_match.group(1))
        unit = weight_match.group(2)
        if unit in ("LTR", "L"):
            return (amount * 1000, "ml")
        if unit == "ML":
            return (amount, "ml")
        if unit == "KG":
            return (amount * 1000, "g")
        if unit in ("G", "GM"):
            return (amount, "g")

    # Count-based units — check explicit "(N)" first, e.g. "DOZEN (12)"
    explicit = re.search(r"\((\d+)\)", text)
    if explicit and any(k in text for k in ("DOZEN", "PACK", "TRAY", "SINGLE")):
        return (float(explicit.group(1)), "count")

    pack_match = re.search(r"PACK\s*OF\s*(\d+)", text) or re.search(r"(\d+)\s*PCS\b", text)
    if pack_match:
        return (float(pack_match.group(1)), "count")

    if "DOZEN" in text:
        return (12.0, "count")
    if "TRAY" in text:
        return (30.0, "count")  # common tray size; adjust if real data shows otherwise
    if "SINGLE" in text:
        return (1.0, "count")

    return None


def _is_multipack(name: str) -> bool:
    """
    True if a variant name indicates a wholesale carton/multi-pack rather
    than a single unit — e.g. "OLPERS MILK 1 LTR - CARTON - 1 LTR X 12".

    Real bug found via live testing: without this check, that carton's
    Rs. 4200 (a 12-bottle pack) was being returned as the price for a
    single 1 L bottle, because the quantity parser found the first "1 LTR"
    text in the name and treated it as an exact match — wildly inflating
    the reported average price. Our catalog only ever asks for single
    units, so multi-pack variants must be excluded, not just quantity-matched.
    """
    name_upper = name.upper()
    if "CARTON" in name_upper:
        return True
    if re.search(r"X\s*\d+\b", name_upper):  # e.g. "X 12", "X 6"
        return True
    return False


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
                # The CARTON/"X N" multipack filter is designed to catch
                # wholesale weight/volume packs (e.g. a 12-bottle carton
                # when a single 1L bottle was wanted). For count-based
                # products like Eggs, "Pack of 6" or "X 6" IS the actual
                # unit being requested, not an unwanted bulk pack — so
                # skip this filter when matching a count-based target.
                if target_qty[1] != "count" and _is_multipack(name):
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