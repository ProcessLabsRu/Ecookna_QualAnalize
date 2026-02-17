import asyncio
from bot.services.analyzer import Analyzer
from unittest.mock import MagicMock

async def test_formatting():
    # Mock session
    session = MagicMock()
    analyzer = Analyzer(session)
    
    # Test 1: _parse_rule_string fix
    print("Testing _parse_rule_string...")
    # Simulate the "48" issue if it was formatted as 4/12/48/4
    # Wait, the user's screenshot had "48" in the MIDDLE of a bracketed list.
    # [5, 10, 48, 4] -> 4 elements? Formula usually has glass-frame-glass...
    # If primary_opt was [5, 10, 4, 8, 4] but rules were bad...
    
    s1 = "4/12/4/8/4"
    p1 = analyzer._parse_rule_string(s1)
    print(f"  '{s1}' -> {p1}")
    
    s2 = "4-12-4"
    p2 = analyzer._parse_rule_string(s2)
    print(f"  '{s2}' -> {p2}")
    
    s3 = "4 12 4"
    p3 = analyzer._parse_rule_string(s3)
    print(f"  '{s3}' -> {p3}")

    s4 = "5x10x4x8x4"
    p4 = analyzer._parse_rule_string(s4)
    print(f"  '{s4}' -> {p4}")

    # Test 2: check_slip message formatting (mocked)
    print("\nTesting check_slip message formatting...")
    # We need to bypass DB check or mock rule
    analyzer._parse_rule_string = MagicMock(side_effect=lambda x: [5, 12, 5, 12, 5] if "3k" in str(x) else [5, 12, 5])
    
    # Mocking self.session.execute(stmt)
    rule = MagicMock()
    rule.formula_1_2k = "5/12/5"
    rule.formula_2_2k = "6/10/6"
    
    # Mock rule lookup
    analyzer.session.execute = MagicMock()
    # We need to make it return a Mock that has scalars().first() -> rule
    result_mock = MagicMock()
    result_mock.scalars().first.return_value = rule
    analyzer.session.execute.return_value = result_mock
    
    # Actual elements (thinner than rule)
    elements = [
        {"thickness": 4, "type": "glass"},
        {"thickness": 10, "type": "frame"},
        {"thickness": 4, "type": "glass"}
    ]
    
    errors = await analyzer.check_slip(1200, 1200, elements)
    if errors:
        print("Generated Error Message:")
        print("-" * 20)
        print(errors[0])
        print("-" * 20)
        
        # Verify line breaks
        if "\n❌" in errors[0] and "\nФормула" in errors[0] and "\n(или:" in errors[0]:
            print("OK: Line breaks found.")
        else:
            print("FAIL: Missing expected line breaks.")
    else:
        print("FAIL: No errors generated.")

if __name__ == "__main__":
    asyncio.run(test_formatting())
