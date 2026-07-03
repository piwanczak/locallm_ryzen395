import assert from "node:assert/strict";
import { priceCart } from "../src/cart.mjs";

const cart = priceCart([
  { sku: "keyboard", quantity: 1 },
  { sku: "mouse", quantity: 2 },
  { sku: "desk-mat", quantity: 2 }
]);

assert.deepEqual(cart.items, [
  { sku: "keyboard", quantity: 1, lineTotalCents: 8900 },
  { sku: "mouse", quantity: 2, lineTotalCents: 8400 },
  { sku: "desk-mat", quantity: 2, lineTotalCents: 5000 }
]);
assert.equal(cart.subtotalCents, 22300);
assert.equal(cart.discountCents, 2200);
assert.equal(cart.totalCents, 20100);

const doubleBundle = priceCart([
  { sku: "keyboard", quantity: 2 },
  { sku: "mouse", quantity: 2 }
]);
assert.equal(doubleBundle.discountCents, 3000);
assert.equal(doubleBundle.totalCents, 23200);

assert.throws(() => priceCart([{ sku: "keyboard", quantity: 0 }]), /positive/i);
assert.throws(() => priceCart([{ sku: "keyboard", quantity: 5 }]), /stock/i);
assert.throws(() => priceCart([{ sku: "missing", quantity: 1 }]), /unknown/i);

console.log("multi-file-cart tests passed");
