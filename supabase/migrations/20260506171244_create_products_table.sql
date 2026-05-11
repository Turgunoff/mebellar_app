-- Products table
CREATE TABLE IF NOT EXISTS public.products (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id   uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  subcategory_id uuid REFERENCES public.subcategories(id) ON DELETE SET NULL,
  shop_id       uuid,
  name          text NOT NULL,
  description   text,
  price         numeric(12, 2) NOT NULL DEFAULT 0,
  images        text[] NOT NULL DEFAULT '{}',
  attributes    jsonb,
  stock         integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read products" ON public.products
  FOR SELECT USING (true);

-- Index for category lookups
CREATE INDEX IF NOT EXISTS products_category_id_idx ON public.products(category_id);
CREATE INDEX IF NOT EXISTS products_subcategory_id_idx ON public.products(subcategory_id);

-- Sample data (using category IDs from categories table)
INSERT INTO public.products (category_id, subcategory_id, name, description, price, images, attributes, stock)
SELECT
  c.id,
  s.id,
  'Velvet Corner Sofa',
  'A luxurious L-shaped velvet corner sofa with solid wood legs. Sink into supreme comfort with high-density foam cushions wrapped in premium velvet fabric.',
  1299000,
  ARRAY[
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80',
    'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1400&q=80',
    'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=1400&q=80'
  ],
  '{"color": "Midnight Blue", "material": "Velvet", "legs": "Solid Oak", "seats": "4–5", "width": "280 cm", "depth": "170 cm", "height": "85 cm"}'::jsonb,
  12
FROM public.categories c
LEFT JOIN public.subcategories s ON s.category_id = c.id AND s.name = 'Corner Sofas'
WHERE c.name = 'Sofas & Armchairs'
LIMIT 1;

INSERT INTO public.products (category_id, subcategory_id, name, description, price, images, attributes, stock)
SELECT
  c.id,
  s.id,
  'Oak Extendable Dining Table',
  'Handcrafted solid oak dining table that extends from 160 cm to 240 cm. Perfect for family dinners and entertaining guests.',
  849000,
  ARRAY[
    'https://images.unsplash.com/photo-1449247709967-d4461a6a6103?w=1400&q=80',
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80'
  ],
  '{"color": "Natural Oak", "material": "Solid Oak", "seats": "6–8", "width": "160–240 cm", "depth": "90 cm", "height": "76 cm"}'::jsonb,
  7
FROM public.categories c
LEFT JOIN public.subcategories s ON s.category_id = c.id AND s.name = 'Dining Tables'
WHERE c.name = 'Tables & Desks'
LIMIT 1;

INSERT INTO public.products (category_id, subcategory_id, name, description, price, images, attributes, stock)
SELECT
  c.id,
  s.id,
  'Scandinavian Platform Bed',
  'Minimalist platform bed in white lacquered MDF with integrated headboard. Features under-bed storage drawers for a clutter-free bedroom.',
  1099000,
  ARRAY[
    'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1400&q=80',
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80'
  ],
  '{"color": "White", "material": "MDF", "size": "160×200 cm", "storage": "2 drawers", "height": "45 cm"}'::jsonb,
  5
FROM public.categories c
LEFT JOIN public.subcategories s ON s.category_id = c.id AND s.name = 'Double Beds'
WHERE c.name = 'Beds & Bedrooms'
LIMIT 1;

INSERT INTO public.products (category_id, name, description, price, images, attributes, stock)
SELECT
  c.id,
  'Industrial Floor Lamp',
  'Adjustable industrial-style floor lamp with matte black finish. Compatible with E27 bulbs up to 40W. Perfect for reading corners and accent lighting.',
  129000,
  ARRAY[
    'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=1400&q=80'
  ],
  '{"color": "Matte Black", "material": "Steel", "height": "165 cm", "bulb": "E27 (not included)", "cable": "1.8 m"}'::jsonb,
  20
FROM public.categories c
WHERE c.name = 'Lighting'
LIMIT 1;
