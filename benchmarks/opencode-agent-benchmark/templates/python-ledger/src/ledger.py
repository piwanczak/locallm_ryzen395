from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP


@dataclass(frozen=True)
class LineItem:
    sku: str
    quantity: int
    unit_price: Decimal


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def invoice_total(items: list[LineItem], discount_percent: Decimal, tax_percent: Decimal) -> Decimal:
    """Return the final invoice total after one invoice-level discount and tax."""
    subtotal = Decimal("0.00")
    for item in items:
        line_total = item.unit_price * item.quantity
        discounted_line = line_total * (Decimal("1.00") - discount_percent / Decimal("100"))
        subtotal += _money(discounted_line)

    with_tax = subtotal * (Decimal("1.00") + tax_percent / Decimal("100"))
    return _money(with_tax)
