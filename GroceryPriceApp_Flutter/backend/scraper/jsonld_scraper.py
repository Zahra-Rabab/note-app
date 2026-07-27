"""
JsonLdScraper — works on ANY store whose product/search pages embed
schema.org "Product" structured data (JSON-LD) in a <script
type="application/ld+json"> tag.
"""

import re
import json
import difflib
from typing import Optional, Any
import requests

from .base_scraper import StoreScraper


def _find_jsonld_blocks(html: str) -> list:
    blocks = []
    for match in re.finditer(
        r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        html,
        re.DOTALL | re.IGNORECASE,
    ):
        raw = match.group(1).strip()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(data, list):
            blocks.extend(data)
        else:
            blocks.append(data)
    return blocks


def _extract_products(blocks: list) -> list:
    products = []

    def _consider(node: Any):
        if not isinstance(node, dict):
            return
        node_type = node.get("@type")
        types = node_type if isinstance(node_type, list) else [node_type]
        if "Product" in types:
            name = node.get("name")
            offers = node.get("offers")
            price = None
            if isinstance(offers, dict):
                price = offers.get("price") or offers.get("lowPrice")
            elif isinstance(offers, list) and offers:
                price = offers[0].get("price") or offers[0].get("lowPrice")
            if name and price is not None:
                try:
                    products.append({"name": str(name), "price": float(price)})
                except (TypeError, ValueError):
                    pass
        if "@graph" in node and isinstance(node["@graph"], list):
            for child in node["@graph"]:
                _consider(child)
        if "itemListElement" in node and isinstance(node["itemListElement"], list):
            for child in node["itemListElement"]:
                inner = child.get("item") if isinstance(child, dict) else None
                _consider(inner if inner else child)

    for block in blocks:
        _consider(block)
    return products


class JsonLdScraper(StoreScraper):
    def __init__(self, store_key: str, config: dict):
        self.store_name = store_key
        self.config = config

    def fetch_price(self, item_name: str) -> Optional[float]:
        url = self.config["search_url_template"].format(
            query=item_name.split(" ")[0]
        )
        headers = self.config.get(
            "headers", {"User-Agent": "Mozilla/5.0 (compatible; GroceryPriceApp/1.0)"}
        )
        try:
            resp = requests.get(url, headers=headers, timeout=12)
            resp.raise_for_status()
        except Exception as e:
            print(f"[{self.store_name}] request failed: {e}")
            return None

        blocks = _find_jsonld_blocks(resp.text)
        products = _extract_products(blocks)
        if not products:
            return None

        target = item_name.lower()
        names = [p["name"].lower() for p in products]
        close = difflib.get_close_matches(target, names, n=1, cutoff=0.3)
        if not close:
            return None
        for p in products:
            if p["name"].lower() == close[0]:
                return p["price"]
        return None
