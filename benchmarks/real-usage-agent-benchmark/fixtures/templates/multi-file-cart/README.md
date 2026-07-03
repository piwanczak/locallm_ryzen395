# Multi-File Cart Fixture

Task: fix `src/cart.mjs` using the rules in `src/catalog.mjs`.

Run:

```powershell
node tools/test.mjs
```

Expected behavior:

- unknown SKUs throw a useful error;
- quantities must be positive integers and cannot exceed stock;
- subtotal is the sum of all line totals;
- bundle discounts from `bundleDiscounts` are applied once per eligible quantity;
- totals stay in integer cents.
