# Backend Quote API Fixture

Task: implement `POST /v1/orders/quote` in `src/orders.mjs`.

Run:

```powershell
node tools/test.mjs
```

Expected behavior:

- accept `customerTier`, `region`, and `items`;
- validate that every item has a known SKU and a positive integer quantity;
- calculate cent-based subtotal, discount, tax, total, and line count;
- return `400` JSON errors for invalid input;
- preserve the existing `GET /health` behavior.
