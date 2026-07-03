import { bundleDiscounts, getProduct } from "./catalog.mjs";

export function priceCart(lines) {
  const items = [];
  const quantities = new Map();

  for (const line of lines) {
    const product = getProduct(line.sku);
    if (!product) {
      throw new Error(`unknown sku: ${line.sku}`);
    }

    const quantity = Number(line.quantity);
    const lineTotalCents = product.priceCents * quantity;
    items.push({ sku: line.sku, quantity, lineTotalCents });
    quantities.set(line.sku, (quantities.get(line.sku) ?? 0) + quantity);
  }

  const subtotalCents = items.reduce((sum, item) => sum + item.lineTotalCents, 0);
  const discountCents = 0;

  return {
    items,
    subtotalCents,
    discountCents,
    totalCents: subtotalCents - discountCents
  };
}
