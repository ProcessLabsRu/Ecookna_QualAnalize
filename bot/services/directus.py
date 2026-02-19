import logging
import aiohttp
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class DirectusClient:
    def __init__(self, base_url: str, token: str, verify_ssl: bool = True):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.verify_ssl = verify_ssl
        
    async def get_items(self, collection: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Получает записи из указанной коллекции Directus.
        """
        url = f"{self.base_url}/items/{collection}"
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            logger.debug(f"Fetching from {url} with params {params}")
            async with session.get(url, headers=headers, params=params, ssl=self.verify_ssl) as response:
                response.raise_for_status()
                data = await response.json()
                return data

    async def get_item_by_id(self, collection: str, item_id: str | int) -> Dict[str, Any]:
        """
        Получает одну запись по ID из коллекции Directus.
        """
        url = f"{self.base_url}/items/{collection}/{item_id}"
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            logger.debug(f"Fetching from {url}")
            async with session.get(url, headers=headers, ssl=self.verify_ssl) as response:
                response.raise_for_status()
                data = await response.json()
                return data
