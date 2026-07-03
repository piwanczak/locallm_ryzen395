const catalog = new Map([
  ["notebook", { priceCents: 1299, taxable: true }],
  ["pen-pack", { priceCents: 450, taxable: true }],
  ["service-plan", { priceCents: 2500, taxable: false }]
]);

const tierDiscounts = new Map([
  ["standard", 0],
  ["silver", 5],
  ["gold", 10]
]);

const regionTaxBps = new Map([
  ["PL", 2300],
  ["DE", 1900],
  ["US-CA", 725]
]);

function json(status, body) {
  return { status, body };
}

export function handleRequest(request) {
  const method = String(request?.method ?? "GET").toUpperCase();
  const path = String(request?.path ?? "/");

  if (method === "GET" && path === "/health") {
    return json(200, { ok: true });
  }

  if (method === "POST" && path === "/v1/orders/quote") {
    return json(501, { error: "quote endpoint not implemented" });
  }

  return json(404, { error: "not found" });
}

export const internals = {
  catalog,
  tierDiscounts,
  regionTaxBps
};
