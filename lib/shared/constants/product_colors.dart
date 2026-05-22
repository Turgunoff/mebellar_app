import 'package:flutter/material.dart';

/// One entry in the catalogue's canonical colour palette.
///
/// [slug] is the locale-independent value persisted to `products.colors`
/// (`text[]`); [label] is the Uzbek display name; [swatch] is the UI fill.
/// This list is the single source of truth shared by the seller's product
/// form/preview and the customer's product detail page — so a colour added
/// here shows up everywhere without further changes.
class ProductColorOption {
  const ProductColorOption({
    required this.slug,
    required this.label,
    required this.swatch,
  });

  final String slug;
  final String label;
  final Color swatch;
}

/// The fixed set of colours a seller can tag a product with.
const List<ProductColorOption> kProductColors = [
  ProductColorOption(slug: 'white', label: 'Oq', swatch: Color(0xFFFFFFFF)),
  ProductColorOption(slug: 'black', label: 'Qora', swatch: Color(0xFF1D1D1D)),
  ProductColorOption(slug: 'grey', label: 'Kulrang', swatch: Color(0xFF9CA3AF)),
  ProductColorOption(
    slug: 'brown',
    label: 'Jigarrang',
    swatch: Color(0xFF8B5E3C),
  ),
  ProductColorOption(slug: 'beige', label: 'Bej', swatch: Color(0xFFE9DCC4)),
  ProductColorOption(slug: 'green', label: 'Yashil', swatch: Color(0xFF4F7A52)),
  ProductColorOption(slug: 'blue', label: "Ko'k", swatch: Color(0xFF3B6CB5)),
  ProductColorOption(slug: 'yellow', label: 'Sariq', swatch: Color(0xFFE6C25C)),
];

/// Resolves a persisted slug to its palette entry, or null when the slug is
/// unknown (e.g. a colour removed from the palette after products were
/// already tagged with it). Callers skip unknown slugs rather than guess.
ProductColorOption? productColorBySlug(String slug) {
  for (final option in kProductColors) {
    if (option.slug == slug) return option;
  }
  return null;
}
