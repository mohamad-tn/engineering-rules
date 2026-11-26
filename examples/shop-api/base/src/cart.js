// Cart totals. Money is an integer in minor units (cents), never a float.
function cartTotal(items) {
  return items.reduce((sum, item) => sum + item.priceMinor * item.quantity, 0);
}

module.exports = { cartTotal };
