import { test } from 'node:test';
import assert from 'node:assert/strict';

import { parseReceipt, isSafeImageUrl } from '../src/lib/ingest/receipt.ts';

const orderEmail = `
<html><body>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Order",
  "orderDate": "2026-08-14",
  "merchant": { "@type": "Organization", "name": "Uniqlo" },
  "acceptedOffer": [
    { "@type": "Offer", "price": "39.90", "priceCurrency": "USD",
      "itemOffered": { "@type": "Product", "name": "Merino Crew Neck Jumper",
        "brand": "Uniqlo", "size": "M",
        "image": "https://image.uniqlo.com/merino.jpg" } },
    { "@type": "Offer", "price": "59.90", "priceCurrency": "USD",
      "itemOffered": { "@type": "Product", "name": "Wide Fit Pleated Trousers",
        "brand": "Uniqlo", "image": "https://image.uniqlo.com/trousers.jpg" } }
  ]
}
</script>
</body></html>`;

test('an order email yields one garment per line, with the price paid', () => {
  const receipt = parseReceipt(orderEmail);

  assert.equal(receipt.method, 'json-ld');
  assert.equal(receipt.merchant, 'Uniqlo');
  assert.equal(receipt.orderedAt, '2026-08-14');
  assert.equal(receipt.items.length, 2);

  const [jumper, trousers] = receipt.items;
  assert.equal(jumper.name, 'Merino Crew Neck Jumper');
  assert.equal(jumper.brand, 'Uniqlo');
  assert.equal(jumper.size, 'M');
  assert.equal(jumper.priceCents, 3990);
  assert.equal(jumper.imageUrl, 'https://image.uniqlo.com/merino.jpg');
  assert.equal(trousers.priceCents, 5990);
});

test('the same product described twice is imported once', () => {
  const doubled = orderEmail.replace(
    '</body>',
    `<script type="application/ld+json">
     {"@type":"Product","name":"Merino Crew Neck Jumper",
      "image":"https://image.uniqlo.com/merino.jpg"}
     </script></body>`,
  );
  assert.equal(parseReceipt(doubled).items.length, 2);
});

test('a malformed block does not lose the rest of the email', () => {
  const broken = orderEmail.replace(
    '</body>',
    '<script type="application/ld+json">{ not json </script></body>',
  );
  assert.equal(parseReceipt(broken).items.length, 2);
});

test('an email with no structured data reports that rather than guessing', () => {
  const receipt = parseReceipt('<html><body><p>Thanks for your order!</p></body></html>');
  assert.equal(receipt.method, 'none');
  assert.equal(receipt.items.length, 0);
});

test('nested schema.org objects resolve to their name', () => {
  const nested = `<script type="application/ld+json">
    {"@type":"Product","name":"Field Jacket",
     "brand":{"@type":"Brand","name":"Barbour"},
     "image":["https://cdn.example.com/a.jpg"]}
  </script>`;
  const [item] = parseReceipt(nested).items;
  assert.equal(item.brand, 'Barbour');
  assert.equal(item.imageUrl, 'https://cdn.example.com/a.jpg');
});

test('image fetching refuses anything that is not a public web address', () => {
  assert.equal(isSafeImageUrl('https://cdn.shop.com/a.jpg'), true);
  assert.equal(isSafeImageUrl('http://cdn.shop.com/a.jpg'), true);

  // A forwarded email is attacker-controlled, so these are SSRF attempts.
  assert.equal(isSafeImageUrl('file:///etc/passwd'), false);
  assert.equal(isSafeImageUrl('http://localhost:54421/rest/v1/garments'), false);
  assert.equal(isSafeImageUrl('http://127.0.0.1/'), false);
  assert.equal(isSafeImageUrl('http://169.254.169.254/latest/meta-data/'), false);
  assert.equal(isSafeImageUrl('http://192.168.1.1/'), false);
  assert.equal(isSafeImageUrl('http://10.0.0.5/'), false);
  assert.equal(isSafeImageUrl(undefined), false);
  assert.equal(isSafeImageUrl('not a url'), false);
});
