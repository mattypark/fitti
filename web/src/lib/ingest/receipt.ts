/**
 * Turn a forwarded order confirmation into garments.
 *
 * This is the highest-leverage way to fill a closet that exists. One forwarded
 * email yields several pieces with brand, size, price, purchase date AND the
 * retailer's own white-background product photo — metadata no camera pipeline
 * will ever match, and a cutout that never needed cutting out.
 *
 * Structured data first, language model second. A surprising share of retailer
 * emails carry schema.org JSON-LD, and parsing that is free, instant and exact.
 * Falling straight to a model would be slower, cost money, and be less accurate
 * on the emails that need it least.
 */

export interface ReceiptItem {
  name: string;
  brand?: string;
  priceCents?: number;
  currency?: string;
  size?: string;
  imageUrl?: string;
  productUrl?: string;
}

export interface ParsedReceipt {
  merchant?: string;
  orderedAt?: string;
  items: ReceiptItem[];
  /** How the items were found, so quality can be measured per source. */
  method: 'json-ld' | 'microdata' | 'none';
}

function toCents(value: unknown): number | undefined {
  if (typeof value === 'number') return Math.round(value * 100);
  if (typeof value !== 'string') return undefined;
  const cleaned = value.replace(/[^0-9.,]/g, '').replace(',', '.');
  const parsed = Number.parseFloat(cleaned);
  return Number.isFinite(parsed) ? Math.round(parsed * 100) : undefined;
}

function firstString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
    if (Array.isArray(value)) {
      const found = value.find((v) => typeof v === 'string' && v.trim());
      if (typeof found === 'string') return found.trim();
    }
    // schema.org lets almost any field be a nested object with a name/url.
    if (value && typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const nested = record.name ?? record.url ?? record['@id'];
      if (typeof nested === 'string' && nested.trim()) return nested.trim();
    }
  }
  return undefined;
}

/** Every JSON-LD block in the document, flattened through @graph. */
function jsonLdBlocks(html: string): Record<string, unknown>[] {
  const blocks: Record<string, unknown>[] = [];
  const pattern = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

  for (const match of html.matchAll(pattern)) {
    try {
      const parsed = JSON.parse(match[1].trim()) as unknown;
      const candidates = Array.isArray(parsed) ? parsed : [parsed];
      for (const candidate of candidates) {
        if (!candidate || typeof candidate !== 'object') continue;
        const record = candidate as Record<string, unknown>;
        if (Array.isArray(record['@graph'])) {
          blocks.push(...(record['@graph'] as Record<string, unknown>[]));
        } else {
          blocks.push(record);
        }
      }
    } catch {
      // A malformed block is not a malformed email. Skip it.
    }
  }
  return blocks;
}

function itemFromProduct(product: Record<string, unknown>): ReceiptItem | null {
  const name = firstString(product.name, product.title);
  if (!name) return null;

  const offers = (Array.isArray(product.offers) ? product.offers[0] : product.offers) as
    | Record<string, unknown>
    | undefined;

  return {
    name,
    brand: firstString(product.brand, product.manufacturer),
    priceCents: toCents(offers?.price ?? product.price),
    currency: firstString(offers?.priceCurrency) ?? 'USD',
    size: firstString(product.size),
    imageUrl: firstString(product.image),
    productUrl: firstString(product.url, offers?.url),
  };
}

export function parseReceipt(html: string): ParsedReceipt {
  const blocks = jsonLdBlocks(html);
  const items: ReceiptItem[] = [];
  let merchant: string | undefined;
  let orderedAt: string | undefined;

  for (const block of blocks) {
    const type = firstString(block['@type']);

    if (type === 'Order') {
      merchant = firstString(block.merchant, block.seller) ?? merchant;
      orderedAt = firstString(block.orderDate) ?? orderedAt;

      const ordered = Array.isArray(block.acceptedOffer)
        ? block.acceptedOffer
        : [block.acceptedOffer].filter(Boolean);

      for (const offer of ordered as Record<string, unknown>[]) {
        const product = offer?.itemOffered as Record<string, unknown> | undefined;
        if (!product) continue;
        const item = itemFromProduct(product);
        if (!item) continue;
        // The order's own offer carries the price actually paid, which beats the
        // product's list price.
        item.priceCents = toCents(offer.price) ?? item.priceCents;
        items.push(item);
      }
    }

    if (type === 'Product') {
      const item = itemFromProduct(block);
      if (item) items.push(item);
    }
  }

  // Two blocks can describe the same product — an Order line and a standalone
  // Product. Same name plus same image is the same thing.
  const seen = new Set<string>();
  const deduped = items.filter((item) => {
    const key = `${item.name.toLowerCase()}|${item.imageUrl ?? ''}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  return {
    merchant,
    orderedAt,
    items: deduped,
    method: deduped.length ? 'json-ld' : 'none',
  };
}

/**
 * Only http(s) images from the email are ever fetched, and only from the public
 * internet. A forwarded email is attacker-controllable input, so an unrestricted
 * fetch here is a server-side request forgery: `file://`, `http://localhost`, or
 * a link to cloud metadata would all be requests our server makes on their behalf.
 */
export function isSafeImageUrl(raw: string | undefined): raw is string {
  if (!raw) return false;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return false;

  const host = url.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.internal')) return false;
  // Literal private ranges and the cloud metadata endpoint.
  if (/^(10\.|127\.|0\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host)) return false;
  if (host === '::1' || host.startsWith('[')) return false;

  return true;
}
