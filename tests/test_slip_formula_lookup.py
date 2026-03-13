import os
import pathlib
import sys

import pytest
from fastapi import HTTPException

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
os.environ.setdefault("BOT_TOKEN", "test-token")
os.environ.setdefault("DB_DSN", "postgresql+asyncpg://user:pass@localhost:5432/testdb")
os.environ.setdefault("DIRECTUS_URL", "http://localhost:8055")
os.environ.setdefault("DIRECTUS_TOKEN", "test-token")

from bot.services.analyzer import Analyzer
from web.app import parse_size_input


class DummyRule:
    marking = "Test Marking"
    formula_1_1k = "4-16-4"
    formula_2_1k = "6-16-4"
    formula_1_2k = "4-10-4-10-4"
    formula_2_2k = None
    formula_1_3k = None
    formula_2_3k = "4-8-4-8-4-8-4"


@pytest.mark.parametrize(
    ("raw_value", "expected"),
    [
        ("1520*2730", (1520, 2730)),
        ("1520x2730", (1520, 2730)),
        ("1520х2730", (1520, 2730)),
        (" 1520 × 2730 ", (1520, 2730)),
    ],
)
def test_parse_size_input_accepts_common_delimiters(raw_value, expected):
    assert parse_size_input(raw_value) == expected


def test_parse_size_input_rejects_invalid_format():
    with pytest.raises(HTTPException) as exc_info:
        parse_size_input("1520/2730")

    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_get_slip_formulas_by_size_returns_grouped_formulas():
    analyzer = Analyzer(session=None)

    async def fake_find_rule(width, height):
        return DummyRule(), 1500, 2700

    analyzer._find_size_control_rule = fake_find_rule

    result = await analyzer.get_slip_formulas_by_size(1520, 2730)

    assert result["found"] is True
    assert result["width_round"] == 1500
    assert result["height_round"] == 2700
    assert result["marking"] == "Test Marking"
    assert result["formulas"]["1k"] == ["4-16-4", "6-16-4"]
    assert result["formulas"]["2k"] == ["4-10-4-10-4"]
    assert result["formulas"]["3k"] == ["4-8-4-8-4-8-4"]


@pytest.mark.asyncio
async def test_get_slip_formulas_by_size_returns_not_found_payload():
    analyzer = Analyzer(session=None)

    async def fake_find_rule(width, height):
        return None, 1500, 2700

    analyzer._find_size_control_rule = fake_find_rule

    result = await analyzer.get_slip_formulas_by_size(1520, 2730)

    assert result == {
        "found": False,
        "width": 1520,
        "height": 2730,
        "width_round": 1500,
        "height_round": 2700,
        "marking": None,
        "formulas": {},
    }
