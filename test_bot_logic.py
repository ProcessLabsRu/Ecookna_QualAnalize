import asyncio
import logging
import os
from bot.database.database import async_session
from bot.services.pdf_parser import PDFParser
from bot.services.analyzer import Analyzer

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def run_test():
    file_path = "docs/examples/тест11022026.pdf"
    
    if not os.path.exists(file_path):
        logger.error(f"File not found: {file_path}")
        return

    logger.info(f"Processing {file_path}...")
    
    # 1. Parse PDF
    try:
        text = PDFParser.extract_text(file_path)
        items = PDFParser.parse_text(text)
        logger.info(f"Extracted {len(items)} items.")
    except Exception as e:
        logger.error(f"Parsing failed: {e}")
        return

    # 2. Analyze
    async with async_session() as session:
        analyzer = Analyzer(session)
        await analyzer.load_films()
        
        for item in items:
            print(f"--- Position {item['position_num']} ---")
            print(f"Original Formula: {item['position_formula']}")
            print(f"Is Outside: {item['is_oytside']}")
            
            elements = analyzer.parse_formula(item['position_formula'], item['is_oytside'])
            print(f"Parsed Elements: {[e['article'] for e in elements]}")
            
            # Check Slip
            w = item['position_width']
            h = item['position_hight']
            errors = await analyzer.check_slip(w, h, elements)
            
            if errors:
                print(f"ERRORS: {errors}")
            else:
                print("Status: OK")
            print("")

if __name__ == "__main__":
    asyncio.run(run_test())
