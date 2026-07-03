export const products = new Map([
  ["keyboard", { priceCents: 8900, stock: 4 }],
  ["mouse", { priceCents: 4200, stock: 8 }],
  ["desk-mat", { priceCents: 2500, stock: 5 }]
]);

export const bundleDiscounts = [
  {
    id: "keyboard-mouse",
    required: { keyboard: 1, mouse: 1 },
    discountCents: 1500
  },
  {
    id: "desk-pair",
    required: { "desk-mat": 2 },
    discountCents: 700
  }
];

export function getProduct(sku) {
  return products.get(sku);
}
