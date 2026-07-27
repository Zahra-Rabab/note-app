"""
Matches free-text user input (any language/spelling) to a canonical product
in products.json.

Matching pipeline:
  1. Normalize the input (lowercase, trim, collapse whitespace).
  2. Exact alias match — if the normalized input exactly equals a known
     alias, that's an instant, 100%-confidence match.
  3. Substring match — if the input contains a known alias or vice versa
     (handles "milk 1L" matching the "milk" alias).
  4. Fuzzy match — edit-distance comparison (via difflib) against every
     known alias, for typos and close variants. Only accepted above a
     confidence threshold, so it doesn't guess wildly.

Honest limitation: fuzzy matching (step 4) works well for Latin-script text
(English, Roman Urdu) because edit-distance on individual characters is a
good proxy for "typo distance" there. It's much weaker for Urdu script,
since a single Urdu character can represent what took several Latin
characters, and OCR/typing typos in Urdu behave differently. Exact and
substring matching (steps 2-3) still work fine for Urdu — so add Urdu
aliases explicitly rather than relying on fuzzy matching to catch typos
in Urdu input.
"""

import json
import re
import difflib
from pathlib import Path
from typing import Optional

CATALOG_FILE = Path(__file__).parent / "products.json"
FUZZY_CONFIDENCE_THRESHOLD = 0.72


def _normalize(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"\s+", " ", text)
    return text


def load_catalog() -> dict:
    with open(CATALOG_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("_")}


def _build_alias_index(catalog: dict) -> list[tuple[str, str]]:
    """Returns a flat list of (normalized_alias, product_key) pairs."""
    index = []
    for key, product in catalog.items():
        for alias in product["aliases"]:
            index.append((_normalize(alias), key))
    return index


def match_product(query: str, catalog: Optional[dict] = None) -> Optional[dict]:
    """
    Returns {product_key, canonical_name, units, default_unit, confidence,
    match_type} for the best match, or None if nothing crosses the
    confidence threshold.
    """
    if catalog is None:
        catalog = load_catalog()

    normalized_query = _normalize(query)
    if not normalized_query:
        return None

    alias_index = _build_alias_index(catalog)

    # Step 2: exact match
    for alias, key in alias_index:
        if alias == normalized_query:
            return _build_result(catalog, key, confidence=1.0, match_type="exact")

    # Step 3: whole-word/phrase match (word-boundary aware, NOT raw substring —
    # raw substring caused a real bug during testing: "completely" contains
    # "tel", which falsely matched the "tel" alias for Cooking Oil. Word
    # boundaries prevent a short alias from matching inside an unrelated word.
    best_substring: Optional[tuple[str, str]] = None
    for alias, key in alias_index:
        pattern = r"\b" + re.escape(alias) + r"\b"
        if re.search(pattern, normalized_query) or re.search(
            r"\b" + re.escape(normalized_query) + r"\b", alias
        ):
            if best_substring is None or len(alias) > len(best_substring[0]):
                best_substring = (alias, key)
    if best_substring:
        return _build_result(catalog, best_substring[1], confidence=0.9, match_type="substring")

    # Step 4: fuzzy match
    all_aliases = [a for a, _ in alias_index]
    close = difflib.get_close_matches(
        normalized_query, all_aliases, n=1, cutoff=FUZZY_CONFIDENCE_THRESHOLD
    )
    if close:
        matched_alias = close[0]
        key = next(k for a, k in alias_index if a == matched_alias)
        confidence = difflib.SequenceMatcher(None, normalized_query, matched_alias).ratio()
        return _build_result(catalog, key, confidence=confidence, match_type="fuzzy")

    return None


def suggest_products(query: str, catalog: Optional[dict] = None, limit: int = 3) -> list[dict]:
    """When there's no confident match, return a few closest candidates
    so the app can show 'Did you mean...?' suggestions."""
    if catalog is None:
        catalog = load_catalog()

    normalized_query = _normalize(query)
    alias_index = _build_alias_index(catalog)
    all_aliases = [a for a, _ in alias_index]

    close = difflib.get_close_matches(normalized_query, all_aliases, n=limit, cutoff=0.4)
    seen_keys = set()
    suggestions = []
    for alias in close:
        key = next(k for a, k in alias_index if a == alias)
        if key in seen_keys:
            continue
        seen_keys.add(key)
        suggestions.append(_build_result(catalog, key, confidence=0.0, match_type="suggestion"))
    return suggestions


def _build_result(catalog: dict, key: str, confidence: float, match_type: str) -> dict:
    product = catalog[key]
    return {
        "productKey": key,
        "canonicalName": product["canonical_name"],
        "units": product["units"],
        "defaultUnit": product["default_unit"],
        "confidence": round(confidence, 2),
        "matchType": match_type,
    }
