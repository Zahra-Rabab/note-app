"""
Every store's price-fetcher implements this interface. This is what makes
the backend "pluggable" — app.py doesn't know or care how each store gets
its prices, it just calls fetch_price() on whichever scrapers are enabled.
"""

from abc import ABC, abstractmethod
from typing import Optional


class StoreScraper(ABC):
    store_name: str = "Unknown"

    @abstractmethod
    def fetch_price(self, item_name: str) -> Optional[float]:
        """Return a price in PKR for the given item, or None if not found."""
        raise NotImplementedError
