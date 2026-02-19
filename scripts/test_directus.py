import asyncio
import logging
import os
import sys

# Добавляем корневую директорию проекта в путь
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from bot.services.directus import DirectusClient

logging.basicConfig(level=logging.DEBUG)

async def test_directus():
    url = "https://rules.entechai.ru"
    token = "ayLIDVMRT_5jmMZ1INwBlQ8p41mNSuYZ"
    
    client = DirectusClient(base_url=url, token=token, verify_ssl=False)
    
    try:
        print(f"Connecting to Directus at {url}...")
        data = await client.get_items("art_rules", params={"limit": 5})
        print("Success fetching 'art_rules':", data)
    except Exception as e:
        print(f"Error fetching 'art_rules': {e}")
        

        
if __name__ == "__main__":
    asyncio.run(test_directus())
