import sys
import os
import logging

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from bot.services.pdf_parser import PDFParser

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_parsing():
    file_path = "docs/examples/00-134-1060 два стеклопакета.pdf"
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    print(f"Extracting text from {file_path}...")
    try:
        text = PDFParser.extract_text(file_path)
        print(f"--- Extracted Text Preview ---\n{text[:500]}\n------------------------------")
        items = PDFParser.parse_text(text)
        
        found = False
        for item in items:
            p_num = item.get("position_num")
            if "00-134-1060" in p_num:
                found = True
                print(f"\n[ITEM FOUND]")
                print(f"Position Num: '{p_num}'")
                print(f"Position Formula: '{item.get('position_formula')}'")
                print(f"Raw Formula Clean: '{item.get('raw_formula')}'")
                print(f"Width x Height: {item.get('position_width')}x{item.get('position_hight')}")
        
        if not found:
            print("Target item NOT FOUND")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_parsing()
