import logging
import re
from typing import List, Optional, Tuple
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from bot.database.models import Film, SizeControl, QualPos, QualIssue

logger = logging.getLogger(__name__)

class Analyzer:
    def __init__(self, session: AsyncSession):
        self.session = session
        self._films_cache: List[str] = []

    async def load_films(self):
        """Loads films from DB to cache."""
        stmt = select(Film.films_article).where(Film.films_article.isnot(None))
        result = await self.session.execute(stmt)
        self._films_cache = [row[0].strip() for row in result.all()]
        logger.info(f"Loaded {len(self._films_cache)} films from DB.")

    def get_thickness(self, p: str) -> int:
        """Extracts thickness from article string (first number found)."""
        match = re.search(r"(\d+)", p)
        return int(match.group(1)) if match else 0

    def parse_formula(self, formula: str, is_outside: bool) -> List[dict]:
        """
        Parses formula into elements, filters films, and handles 'is_outside' order.
        Returns list of dict: {'article': str, 'type': 'glass'|'frame', 'thickness': int}
        """
        if not formula:
            return []
        
        # Split by 'x' or 'х' (Cyrillic)
        raw_parts = re.split(r"[xх]", formula)
        elements = []

        for part in raw_parts:
            article = part.strip()
            if not article:
                continue

            # Filter Films
            # We assume self._films_cache is populated.
            # strict check: article in films
            if article in self._films_cache:
                continue

            # Determine type (Glass vs Frame)
            # Logic from SQL: ^[HWНШ] -> frame, else glass
            # Also common sense: frames usually start with letters indicating spacer
            is_frame = re.match(r"^[HWНШ]", article, re.IGNORECASE)
            etype = "frame" if is_frame else "glass"
            
            thickness = self.get_thickness(article)
            
            elements.append({
                "article": article,
                "type": etype,
                "thickness": thickness
            })
        
        # If is_outside, reverse the elements order
        # Requirement: "Outside -> Inside" normalization
        # If formula is given as "Inside -> Outside" (standard), and is_outside=True, 
        # it means the string we see is actually "Outside -> Inside"? 
        # Wait, let's re-read the SQL logic I wrote earlier:
        # IF v_is_outside THEN
        #   SELECT array_agg(elem ORDER BY nr DESC) ...
        # END IF;
        # Since standard formulas are typically listed Outer->Inner (or vice versa depending on factory),
        # but the check logic expects [Glass1, Frame1, Glass2...].
        # The user said: "when is_outside is true, reverse the formula order"
        # So we do exactly that.
        if is_outside:
            elements.reverse()
            
        return elements

    def _round_size(self, value: int) -> int:
        """
        Rounds size to nearest 100 with threshold 51.
        Logic from trg_calc_qual_pos:
        (val / 100) * 100 + (100 if val % 100 >= 51 else 0)
        """
        base = (value // 100) * 100
        remainder = value % 100
        return base + 100 if remainder >= 51 else base

    def _calc_cam_count(self, formula: str) -> int:
        """
        Calculates chamber count based on regex count of 'xH', 'xW' etc.
        Logic: regexp_count(formula, '[xх][нНhHwW]')
        """
        if not formula:
            return 0
        return len(re.findall(r"[xх][нНhHwW]", formula, re.IGNORECASE))

    async def check_slip(self, width: int, height: int, formula_elements: List[dict]) -> List[str]:
        """
        Validates the formula against size_control table.
        Returns a list of error strings.
        """
        errors = []
        
        # 0. Round dimensions
        w_round = self._round_size(width)
        h_round = self._round_size(height)
        
        # 1. Extract extraction thicknesses
        actual_thicknesses = [e["thickness"] for e in formula_elements]
        if not actual_thicknesses:
            return ["Empty formula elements"]

        # 2. Calculate Cam Count
        # We need the original formula string for this, usually. 
        # But we can reconstruct or pass it. 
        # Ideally check_slip receives the FULL item or we calc it before.
        # Let's assume we can calc it from the elements types? 
        # No, 'xH' implies Spacer. An element with type 'frame' is a Spacer.
        # Let's count 'frame' elements from parsed list.
        # Actually SQL uses regex on string. Let's trust SQL logic is better matching spacers.
        # But here we don't have the string passed easily unless we change signature.
        # Let's change signature? Or just use frames count.
        # SQL: `regexp_count(..., '[xх][нНhHwW]')`. H/W/N are spacers.
        # My parsed elements 'type'='frame' is based on `^[HWНШ]`. Matches perfectly.
        cam_count = sum(1 for e in formula_elements if e["type"] == "frame")
        
        # 3. Find matching rule
        # Search by rounded dims, orientation independent
        stmt = select(SizeControl).where(
            or_(
                and_(SizeControl.dim1 == w_round, SizeControl.dim2 == h_round),
                and_(SizeControl.dim1 == h_round, SizeControl.dim2 == w_round)
            )
        ).limit(1)
        result = await self.session.execute(stmt)
        rule = result.scalars().first()
        
        if not rule:
            return [f"No slip rule found for size {w_round}x{h_round}"]

        # 4. Select Formulas based on Cam Count
        f1_text = None
        f2_text = None
        
        if cam_count == 0:
            return [] # No slip check for single glass / panels

        if cam_count == 1:
            f1_text = rule.formula_1_1k
            f2_text = rule.formula_2_1k
        elif cam_count == 2:
            f1_text = rule.formula_1_2k
            f2_text = rule.formula_2_2k
        elif cam_count == 3:
            f1_text = rule.formula_1_3k
            f2_text = rule.formula_2_3k
        
        if not f1_text and not f2_text:
             return [f"No formulas found for {cam_count} chambers in rule {w_round}x{h_round}"]

        valid_options = []
        if f1_text: valid_options.append(self._parse_rule_string(f1_text))
        if f2_text: valid_options.append(self._parse_rule_string(f2_text))
        
        match_found = False
        for opt in valid_options:
            if actual_thicknesses == opt:
                match_found = True
                break
                
        if not match_found:
             msg = f"Mismatch! Actual: {actual_thicknesses}. Expected: {valid_options}"
             errors.append(msg)

        return errors

    def _parse_rule_string(self, rule_str: str) -> List[int]:
        """
        Parses a rule string like '4/12/4/12/4', '4-12-4', '4 12 4' into [4,12,4].
        """
        # Finds all consecutive digit sequences
        parts = re.findall(r"\d+", rule_str)
        return [int(p) for p in parts]
