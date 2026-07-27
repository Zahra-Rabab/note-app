"""
GenericJsonApiScraper drives itself entirely from store_configs.json.

Once you've found a store's internal search API (see HOW_TO_FIND_APIS.md),
you don't need to write a new Python class for it — just fill in its entry
in store_configs.json:

  "imtiaz": {
    "enabled": true,
    "search_url_template": "https://shop.imtiaz.com.pk/api/search?q={query}",
    "headers": {"User-Agent": "Mozilla/5.0"},
    "results_path": ["data", "products"],
    "name_field": "title",
    "price_field": "price"
  }

- search_url_template: the URL you saw in the Network tab, with the search
  term replaced by {query}.
- results_path: the list of keys to walk through the JSON response to reach
  the list of products. E.g. if the response looks like
  {"data": {"products": [...]}} then results_path is ["data", "products"].
- name_field / price_field: the key names inside each product object.

This covers the common case (a JSON search API). Sites that need a login,
a session token, or return HTML instead of JSON will need a bit more work —
ask me for help once you've inspected one and I'll adjust this or write a
dedicated scraper for it.
"""

import json
import re
from pathlib import Path
from typing import Optional, Any
import requests

from .base_scraper import StoreScraper

CONFIG_FILE = Path(__file__).parent / "store_configs.json"


def _dig(data: Any, path: list[str]) -> Any:
    for key in path:
        if isinstance(data, dict) and key in data:
            data = data[key]
        else:
            return None
    return data


def _parse_price(value: Any) -> Optional[float]:
    """
    Parses prices like 330, "330", "Rs. 330", "Rs.1,450.50", "PKR 1,450" etc.
    Deliberately requires the match to START with a digit, so stray periods
    from prefixes like "Rs." don't get swept into the number (that bug
    turned "Rs. 330" into 0.33 during testing — this regex fixes it).
    """
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)

    match = re.search(r"\d[\d,]*\.?\d*", str(value))
    if not match:
        return None
    return float(match.group(0).replace(",", ""))



class GenericJsonApiScraper(StoreScraper):
    def __init__(self, store_key: str, config: dict):
        self.store_name = store_key
        self.config = config

    def fetch_price(self, item_name: str) -> Optional[float]:
        url = self.config["search_url_template"].format(query=item_name.replace(" ", "+"))
        headers = self.config.get("headers", {})

        try:
            resp = requests.get(url, headers=headers, timeout=10)
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            print(f"[{self.store_name}] request failed: {e}")
            return None

        products = _dig(data, self.config["results_path"]) or []
        if not isinstance(products, list) or not products:
            return None

        # Use the first matching product. Good enough for an MVP —
        # you can improve matching (fuzzy match, pick cheapest, etc.) later.
        target = item_name.lower()
        best = None
        for product in products:
            name = str(product.get(self.config["name_field"], "")).lower()
            if target in name or name in target:
                best = product
                break
        if best is None:
            best = products[0]

        return _parse_price(best.get(self.config["price_field"]))


def load_enabled_scrapers() -> list[StoreScraper]:
    if not CONFIG_FILE.exists():
        return []
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        configs = json.load(f)

    scrapers = []
    for store_key, config in configs.items():
        if store_key.startswith("_"):
            continue
        if not config.get("enabled"):
            continue

        if config.get("type") == "dedicated":
            # Some stores (e.g. Alfatah) need custom logic — category-based
            # navigation, quantity-aware matching — that a generic config
            # can't express. Those live as their own StoreScraper subclass
            # and are registered here instead of built from JSON config.
            if store_key == "alfatah":
                from .alfatah_scraper import AlfatahScraper
                scrapers.append(AlfatahScraper())
            continue

        if config.get("type") == "jsonld":
            from .jsonld_scraper import JsonLdScraper
            scrapers.append(JsonLdScraper(store_key, config))
            continue

        scrapers.append(GenericJsonApiScraper(store_key, config))
    return scrapers
