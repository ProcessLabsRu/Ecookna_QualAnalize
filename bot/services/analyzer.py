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
            return ["Пустая формула"]

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
            return [f"Не найдено правило слипания для размера {w_round}x{h_round}"]

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
             return [f"Не найдены допустимые формулы для {cam_count}-камерного пакета в правиле {w_round}x{h_round}"]

        valid_options = []
        if f1_text: valid_options.append(self._parse_rule_string(f1_text))
        if f2_text: valid_options.append(self._parse_rule_string(f2_text))
        
        match_found = False
        for opt in valid_options:
            if len(actual_thicknesses) == len(opt):
                # Check if ALL elements are >= required (Pass condition)
                if all(act >= exp for act, exp in zip(actual_thicknesses, opt)):
                    match_found = True
                    break
        
        if not match_found:
             # Generate specific mismatch details avoiding "Mismatch!" title if possible, or make it descriptive
             # We compare against the first valid option as primary reference
             primary_opt = valid_options[0]
             
             details = []
             # Check lengths first
             limit = min(len(actual_thicknesses), len(primary_opt))
             
             for i in range(limit):
                 act = actual_thicknesses[i]
                 exp = primary_opt[i]
                 
                 # Error only if strictly LESS than required
                 if act < exp:
                     # Determine element name
                     el_type = formula_elements[i]['type']
                     # Count index of this type
                     cnt = sum(1 for x in formula_elements[:i+1] if x['type'] == el_type)
                     
                     if el_type == 'glass':
                         type_name = "стекло"
                         suffix = "-е"
                         if cnt == 3: suffix = "-е" 
                         name_str = f"{cnt}{suffix} {type_name}"
                     else:
                         type_name = "рамка"
                         suffix = "-я"
                         if cnt == 3: suffix = "-я" 
                         name_str = f"{cnt}{suffix} {type_name}"
                     
                     details.append(f"{name_str}: {act} мм (в заказе) < {exp} мм (норма)")
             
             # If details is empty but match_found is False, it implies logic error or length mismatch?
             # Or maybe it failed against primary_opt but passed against another? No, we checked all.
             # If details empty here, it means for primary_opt everything is >=. 
             # But we are here because NO option was fully >=.
             # So primary_opt MUST have some < failures OR length mismatch.
             
             if details:
                 # Construct message
                 msg = "Обнаружено несоответствие:\n"
                 msg += "\n".join([f"❌ {d}" for d in details]) + "\n"
                 
                 msg += f"\nФормула из заказа: {actual_thicknesses}\n"
                 
                 if len(valid_options) > 1:
                     for i, opt in enumerate(valid_options, 1):
                         msg += f"Формула по таблице слипаемости {i}: {opt}\n"
                 else:
                     msg += f"Формула по таблице слипаемости: {valid_options[0]}"

                 errors.append(msg)

        return errors

    def _parse_rule_string(self, rule_str: str) -> List[int]:
        """
        Parses a rule string like '4/12/4/12/4', '4-12-4', '4 12 4', '4x12x4' into [4,12,4].
        """
        if not rule_str:
            return []
        
        # Split by non-digit characters that are common separators: / - x х (cyrillic) , space
        # We include comma here too to handle the case where it was already a comma-list in the DB
        # or if it was partially parsed.
        parts = re.split(r"[/xх\-\s,]+", rule_str)
        return [int(p) for p in parts if p.isdigit()]
