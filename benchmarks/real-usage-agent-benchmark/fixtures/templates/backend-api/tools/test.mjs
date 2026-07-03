import assert from "node:assert/strict";
import { handleRequest } from "../src/orders.mjs";

function post(body) {
  return handleRequest({ method: "POST", path: "/v1/orders/quote", body });
}

assert.deepEqual(handleRequest({ method: "GET", path: "/health" }), {
  status: 200,
  body: { ok: true }
});

assert.deepEqual(
  post({
    customerTier: "gold",
    region: "US-CA",
    items: [
      { sku: "notebook", quantity: 2 },
      { sku: "pen-pack", quantity: 3 },
      { sku: "service-plan", quantity: 1 }
    ]
  }),
  {
    status: 200,
    body: {
      subtotalCents: 6448,
      discountCents: 645,
      taxableCents: 3553,
      taxCents: 258,
      totalCents: 6061,
      lineCount: 3
    }
  }
);

assert.deepEqual(
  post({
    customerTier: "silver",
    region: "DE",
    items: [{ sku: "pen-pack", quantity: 2 }]
  }),
  {
    status: 200,
    body: {
      subtotalCents: 900,
      discountCents: 45,
      taxableCents: 855,
      taxCents: 162,
      totalCents: 1017,
      lineCount: 1
    }
  }
);

for (const body of [
  { customerTier: "gold", region: "US-CA", items: [] },
  { customerTier: "gold", region: "US-CA", items: [{ sku: "missing", quantity: 1 }] },
  { customerTier: "gold", region: "US-CA", items: [{ sku: "notebook", quantity: 0 }] },
  { customerTier: "platinum", region: "US-CA", items: [{ sku: "notebook", quantity: 1 }] },
  { customerTier: "gold", region: "unknown", items: [{ sku: "notebook", quantity: 1 }] }
]) {
  const result = post(body);
  assert.equal(result.status, 400, `expected 400 for ${JSON.stringify(body)}`);
  assert.match(result.body.error, /invalid|unknown|required|positive|items/i);
}

console.log("backend-api tests passed");
