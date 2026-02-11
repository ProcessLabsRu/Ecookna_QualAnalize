import re
import pdfplumber
import logging
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

class PDFParser:
    # Regex Patterns
    # Номер: допускаем пробелы/переносы внутри
    # 1: Number, 2: Raw Formula, 3: Thickness, 4: Width, 5: Height, 6: Count, 7: Area, 8: Mass
    ITEM_RE = re.compile(
        r"(\d{2}-\d{3}-\s*\d{4}\/\d+\/\d+(?:[\/\w-]*))\s+([\s\S]*?)\s*\(\s*(\d+)(?:\s*мм)?\s*\)(?:\s*мм)?\s+(\d+)\s*[x×хХ]\s*(\d+)\s+(\d+)\s+([\d.,]+)\s+([\d.,]+)",
        re.IGNORECASE
    )
    
    LAYOUT_RE = re.compile(r"Раскладка\s+([^\r\n]+)", re.IGNORECASE)
    SPLIT_RE = re.compile(r"Итого по изделию:", re.IGNORECASE)

    @staticmethod
    def extract_text(file_path: str) -> str:
        """Extracts full text from a PDF file using pdfplumber."""
        full_text = []
        try:
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        full_text.append(text)
            return "\n".join(full_text)
        except Exception as e:
            logger.error(f"Error extracting text from {file_path}: {e}")
            raise

    @staticmethod
    def parse_text(text: str) -> List[Dict]:
        """Parses the extracted text into structural items."""
        items = []
        blocks = PDFParser.SPLIT_RE.split(text)

        for block in blocks:
            # Extract Layout (Raskladka) if present in the block
            layout_match = PDFParser.LAYOUT_RE.search(block)
            layout = layout_match.group(1).strip() if layout_match else "отсутствует"

            # Iterate over all items in the block
            matches = list(PDFParser.ITEM_RE.finditer(block))
            for i, m in enumerate(matches):
                # 1. Extract raw groups
                raw_num = m.group(1)
                raw_formula = m.group(2)
                raw_thick = m.group(3)
                raw_width = m.group(4)
                raw_height = m.group(5)
                raw_count = m.group(6)
                raw_area = m.group(7)
                raw_mass = m.group(8)

                # 2. Extract Post-Context (text after this item until next item or end)
                start, end = m.span()
                if i + 1 < len(matches):
                    next_start = matches[i+1].start()
                    post_context = block[end:next_start]
                else:
                    post_context = block[end:]

                # 3. Clean and Normalize
                position_num = raw_num.replace(" ", "").replace("\n", "").strip()
                
                # Check is_outside in formula AND post_context
                # Clean formula only for formula analysis, but using raw+context for flags
                raw_formula_clean = re.sub(r"\s+", " ", raw_formula).strip()
                
                full_text_check = (raw_formula_clean + " " + post_context).upper()
                
                is_outside = (
                    "СНАРУЖИ" in full_text_check or 
                    "НАРУЖУ" in full_text_check or 
                    re.search(r"FS\b", full_text_check) is not None or # FS word boundary
                    raw_formula_clean.upper().endswith("FS") 
                )

                # Normalize formula (take suffix after last space)
                # "82 Вид СНАРУЖИ на себя 4ИxН14x4М1xН14x4И" -> "4ИxН14x4М1xН14x4И"
                if " " in raw_formula_clean:
                    position_formula = raw_formula_clean.split(" ")[-1]
                else:
                    position_formula = raw_formula_clean

                # Parse numbers
                try:
                    width = int(raw_width)
                    height = int(raw_height)
                    count = int(raw_count)
                    area = float(raw_area.replace(",", "."))
                    mass = float(raw_mass.replace(",", "."))
                    # thick = int(raw_thick) # stored but not strictly used in main struct yet?
                except ValueError as e:
                    logger.warning(f"Error parsing numbers for item {position_num}: {e}")
                    continue

                items.append({
                    "position_num": position_num,
                    "position_formula": position_formula,
                    "position_raskl": layout,
                    "position_width": width,
                    "position_hight": height,
                    "position_count": count,
                    "position_area": area,
                    "position_mass": mass,
                    "is_oytside": is_outside,
                    "raw_formula": raw_formula_clean # debugging
                })
        
        return items
