import pathlib
import sys
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ledger import LineItem, invoice_total


def check(name, actual, expected):
    if actual != expected:
        raise AssertionError(f"{name}: expected {expected}, got {actual}")


items = [
    LineItem("A-100", 3, Decimal("19.995")),
    LineItem("B-205", 2, Decimal("4.335")),
    LineItem("C-900", 1, Decimal("199.99")),
]

check(
    "invoice-level rounding",
    invoice_total(items, Decimal("12.5"), Decimal("8.25")),
    Decimal("254.11"),
)

check(
    "zero discount",
    invoice_total([LineItem("Z", 7, Decimal("0.99"))], Decimal("0"), Decimal("0")),
    Decimal("6.93"),
)

check(
    "fractional unit prices",
    invoice_total([LineItem("F", 3, Decimal("0.335"))], Decimal("10"), Decimal("0")),
    Decimal("0.90"),
)

print("python-ledger tests passed")
