import re
from typing import List

# Copying logic from analyzer.py to verify it in isolation
def _parse_rule_string(rule_str: str) -> List[int]:
    if not rule_str:
        return []
    if re.search(r"[/xх\-\s]", rule_str):
        parts = re.split(r"[/xх\-\s,]+", rule_str)
        return [int(p) for p in parts if p.isdigit()]
    parts = re.findall(r"\d+", rule_str)
    return [int(p) for p in parts]

def test_formatting():
    print("Testing _parse_rule_string logic...")
    tests = [
        ("4/12/4/8/4", [4, 12, 4, 8, 4]),
        ("4-12-4", [4, 12, 4]),
        ("4 12 4", [4, 12, 4]),
        ("5x10x4x8x4", [5, 10, 4, 8, 4]),
        ("5х10х4х8х4", [5, 10, 4, 8, 4]), # Cyrillic 'х'
        ("5, 10, 48, 4", [5, 10, 48, 4]), # Should still find 48 if no separators
    ]
    
    for s, expected in tests:
        actual = _parse_rule_string(s)
        print(f"  '{s}' -> {actual} {'OK' if actual == expected else 'FAIL'}")

    print("\nTesting message formatting structure...")
    # Mock data
    primary_opt = [5, 12, 5, 12, 5]
    actual_thicknesses = [4, 10, 4, 10, 4]
    details = ["1-я рамка: 10 мм (в заказе) < 12 мм (норма)", "2-я рамка: 10 мм (в заказе) < 12 мм (норма)"]
    valid_options = [[5, 12, 5, 12, 5], [6, 10, 6]]
    
    msg = "Обнаружено несоответствие:\n"
    msg += "\n".join([f"❌ {d}" for d in details]) + "\n"
    msg += f"\nФормула из заказа: {actual_thicknesses}\n"
    
    if len(valid_options) > 1:
        for i, opt in enumerate(valid_options, 1):
            msg += f"Формула по таблице слипаемости {i}: {opt}\n"
    else:
        msg += f"Формула по таблице слипаемости: {valid_options[0]}"
    
    print("-" * 20)
    print(msg)
    print("-" * 20)
    
    if "\n❌" in msg and "\nФормула" in msg and "Формула по таблице слипаемости 1:" in msg:
        print("OK: Line breaks and numbered formulas found.")
    else:
        print("FAIL: Missing expected line breaks or numbering.")

if __name__ == "__main__":
    test_formatting()
