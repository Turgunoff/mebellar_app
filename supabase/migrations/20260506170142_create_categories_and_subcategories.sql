-- Categories table
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  subtitle text,
  image_url text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Subcategories table
create table public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

-- RLS
alter table public.categories enable row level security;
alter table public.subcategories enable row level security;

create policy "Public read categories"
  on public.categories for select using (true);

create policy "Public read subcategories"
  on public.subcategories for select using (true);

-- Indexes
create index on public.subcategories (category_id);
create index on public.categories (sort_order);

-- Sample data
insert into public.categories (name, subtitle, image_url, sort_order) values
  ('Sofas & Armchairs',  'Living Room',        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80', 1),
  ('Tables & Desks',     'Dining & Work',      'https://images.unsplash.com/photo-1449247709967-d4461a6a6103?w=1400&q=80', 2),
  ('Beds & Bedrooms',    'Rest',               'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1400&q=80', 3),
  ('Chairs & Seating',   'Lounge',             'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=1400&q=80', 4),
  ('Lighting',           'Ambience',           'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=1400&q=80', 5),
  ('Storage & Wardrobes','Organization',       'https://images.unsplash.com/photo-1595428774223-ef52624120d2?w=1400&q=80', 6),
  ('Decor & Accents',    'Finishing Touches',  'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1400&q=80', 7),
  ('Outdoor Living',     'Garden & Terrace',   'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1400&q=80', 8);

-- Sample subcategories
insert into public.subcategories (category_id, name)
select c.id, s.name
from public.categories c
join (values
  ('Sofas & Armchairs', 'Corner Sofas'),
  ('Sofas & Armchairs', '3-Seater Sofas'),
  ('Sofas & Armchairs', 'Armchairs'),
  ('Sofas & Armchairs', 'Sofa Beds'),
  ('Tables & Desks',    'Dining Tables'),
  ('Tables & Desks',    'Coffee Tables'),
  ('Tables & Desks',    'Study Desks'),
  ('Tables & Desks',    'Console Tables'),
  ('Beds & Bedrooms',   'Double Beds'),
  ('Beds & Bedrooms',   'Single Beds'),
  ('Beds & Bedrooms',   'Bedside Tables'),
  ('Chairs & Seating',  'Bar Stools'),
  ('Chairs & Seating',  'Accent Chairs'),
  ('Lighting',          'Floor Lamps'),
  ('Lighting',          'Pendant Lights'),
  ('Storage & Wardrobes','Wardrobes'),
  ('Storage & Wardrobes','Shelving Units')
) as s(cat_name, name) on c.name = s.cat_name;
