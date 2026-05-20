-- Seeds attribute_definitions + attribute_options for the eight categories
-- created in 20260506170142_create_categories_and_subcategories.sql. Inserts
-- are idempotent (ON CONFLICT DO NOTHING) so re-running the migration is
-- safe — admins can ALTER labels in Studio without the seed clobbering them.
--
-- Sort-order convention: 10, 20, 30 ... leaves room to slot a new attribute
-- between two existing ones without re-numbering every row.

-- ============================================================
-- SOFAS & ARMCHAIRS
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('fabric_type',     'Mato turi',       'Тип ткани',     'select', null::text, true,  10),
  ('seats',           'O''rinlar soni',  'Кол-во мест',   'number', null,        false, 20),
  ('width_cm',        'Eni',             'Ширина',        'number', 'sm',        true,  30),
  ('depth_cm',        'Chuqurligi',      'Глубина',       'number', 'sm',        false, 40),
  ('height_cm',       'Bo''yi',          'Высота',        'number', 'sm',        false, 50),
  ('frame_material',  'Karkas materiali','Материал каркаса','select', null,      false, 60)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Sofas & Armchairs'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('velour',      'Velur',     'Велюр',      10),
  ('loft',        'Loft',      'Лофт',       20),
  ('eko_leather', 'Eko-teri',  'Эко-кожа',   30),
  ('leather',     'Teri',      'Кожа',       40),
  ('fabric',      'Mato',      'Ткань',      50)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'fabric_type'
  and ad.category_id = (select id from public.categories where name = 'Sofas & Armchairs')
on conflict (attribute_id, value) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('wood',   'Yog''och', 'Дерево', 10),
  ('metal',  'Metall',   'Металл', 20),
  ('mixed',  'Aralash',  'Смешанный', 30)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'frame_material'
  and ad.category_id = (select id from public.categories where name = 'Sofas & Armchairs')
on conflict (attribute_id, value) do nothing;

-- Subcategory: Corner Sofas — corner orientation
insert into public.attribute_definitions
  (subcategory_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select s.id, 'corner_side', 'Burchak yo''nalishi', 'Сторона угла', 'select', null, true, 5
from public.subcategories s
where s.name = 'Corner Sofas'
on conflict (subcategory_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('left',      'Chap',       'Левый',      10),
  ('right',     'O''ng',      'Правый',     20),
  ('universal', 'Universal',  'Универсальный', 30)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'corner_side'
  and ad.subcategory_id = (select id from public.subcategories where name = 'Corner Sofas')
on conflict (attribute_id, value) do nothing;

-- Subcategory: Sofa Beds — mattress type
insert into public.attribute_definitions
  (subcategory_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select s.id, 'sleeper_mechanism', 'Yotoq mexanizmi', 'Механизм раскладки', 'select', null, false, 5
from public.subcategories s
where s.name = 'Sofa Beds'
on conflict (subcategory_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('eurobook',   'Yevrokitob',  'Еврокнижка',   10),
  ('dolphin',    'Delfin',      'Дельфин',      20),
  ('accordion',  'Akkordeon',   'Аккордеон',    30),
  ('click_clack','Klik-klak',   'Клик-кляк',    40)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'sleeper_mechanism'
  and ad.subcategory_id = (select id from public.subcategories where name = 'Sofa Beds')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- TABLES & DESKS
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('top_material', 'Stol usti materiali', 'Материал столешницы', 'select', null::text, true,  10),
  ('seats',        'O''rinlar soni',      'Кол-во мест',         'number', null,        false, 20),
  ('width_cm',     'Eni',                 'Ширина',              'number', 'sm',        true,  30),
  ('depth_cm',     'Chuqurligi',          'Глубина',             'number', 'sm',        false, 40),
  ('height_cm',    'Bo''yi',              'Высота',              'number', 'sm',        false, 50),
  ('extendable',   'Yoyiluvchi',          'Раздвижной',          'bool',   null,        false, 60)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Tables & Desks'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('solid_wood', 'Massiv yog''och', 'Массив дерева', 10),
  ('mdf',        'MDF',             'МДФ',           20),
  ('ldsp',       'LDSP',            'ЛДСП',          30),
  ('glass',      'Shisha',          'Стекло',        40),
  ('marble',     'Marmar',          'Мрамор',        50),
  ('metal',      'Metall',          'Металл',        60)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'top_material'
  and ad.category_id = (select id from public.categories where name = 'Tables & Desks')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- BEDS & BEDROOMS
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('mattress_size',      'Matras o''lchami',       'Размер матраса',     'select', null::text, true,  10),
  ('headboard_material', 'Bosh tomon materiali',   'Материал изголовья', 'select', null,        false, 20),
  ('storage',            'Saqlash joyi',           'Ящики для хранения', 'bool',   null,        false, 30),
  ('width_cm',           'Eni',                    'Ширина',             'number', 'sm',        false, 40),
  ('height_cm',          'Bo''yi',                 'Высота',             'number', 'sm',        false, 50)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Beds & Bedrooms'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('90x200',  '90×200 sm',  '90×200 см',  10),
  ('120x200', '120×200 sm', '120×200 см', 20),
  ('140x200', '140×200 sm', '140×200 см', 30),
  ('160x200', '160×200 sm', '160×200 см', 40),
  ('180x200', '180×200 sm', '180×200 см', 50),
  ('200x200', '200×200 sm', '200×200 см', 60)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'mattress_size'
  and ad.category_id = (select id from public.categories where name = 'Beds & Bedrooms')
on conflict (attribute_id, value) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('wood',    'Yog''och',     'Дерево',          10),
  ('mdf',     'MDF',          'МДФ',             20),
  ('fabric',  'Yumshoq mato', 'Мягкая обивка',   30),
  ('leather', 'Teri',         'Кожа',            40)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'headboard_material'
  and ad.category_id = (select id from public.categories where name = 'Beds & Bedrooms')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- CHAIRS & SEATING
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('seat_material', 'O''tirgich materiali', 'Материал сиденья', 'select', null::text, true,  10),
  ('max_weight_kg', 'Maksimal og''irlik',   'Макс. нагрузка',   'number', 'kg',        false, 20),
  ('adjustable',    'Balandlik sozlanadi',  'Регулируемая высота','bool', null,        false, 30),
  ('width_cm',      'Eni',                  'Ширина',           'number', 'sm',        false, 40),
  ('height_cm',     'Bo''yi',               'Высота',           'number', 'sm',        false, 50)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Chairs & Seating'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('fabric',     'Mato',           'Ткань',     10),
  ('leather',    'Teri',           'Кожа',      20),
  ('eko_leather','Eko-teri',       'Эко-кожа',  30),
  ('mesh',       'To''r',          'Сетка',     40),
  ('wood',       'Yog''och',       'Дерево',    50),
  ('plastic',    'Plastik',        'Пластик',   60)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'seat_material'
  and ad.category_id = (select id from public.categories where name = 'Chairs & Seating')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- LIGHTING
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('bulb_type',       'Lampochka turi',     'Тип цоколя',         'select', null::text, true,  10),
  ('bulb_max_w',      'Maks. quvvat',       'Макс. мощность',     'number', 'W',         false, 20),
  ('light_color_temp','Yorug''lik rangi',   'Цветовая температура','select',null,        false, 30),
  ('cable_length_cm', 'Shnur uzunligi',     'Длина шнура',        'number', 'sm',        false, 40),
  ('height_cm',       'Bo''yi',             'Высота',             'number', 'sm',        false, 50)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Lighting'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('e27',         'E27',         'E27',         10),
  ('e14',         'E14',         'E14',         20),
  ('gu10',        'GU10',        'GU10',        30),
  ('led_built_in','O''rnatilgan LED','Встроенный LED',40)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'bulb_type'
  and ad.category_id = (select id from public.categories where name = 'Lighting')
on conflict (attribute_id, value) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('warm',    'Iliq (2700–3000K)',  'Тёплый (2700–3000K)',  10),
  ('neutral', 'Neytral (3500–4500K)','Нейтральный (3500–4500K)',20),
  ('cool',    'Sovuq (5000–6500K)', 'Холодный (5000–6500K)', 30)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'light_color_temp'
  and ad.category_id = (select id from public.categories where name = 'Lighting')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- STORAGE & WARDROBES
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('doors',       'Eshiklar soni',  'Кол-во дверей',  'number', null::text, false, 10),
  ('mirror',      'Oyna',           'Зеркало',        'bool',   null,        false, 20),
  ('width_cm',    'Eni',            'Ширина',         'number', 'sm',        true,  30),
  ('depth_cm',    'Chuqurligi',     'Глубина',        'number', 'sm',        false, 40),
  ('height_cm',   'Bo''yi',         'Высота',         'number', 'sm',        false, 50)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Storage & Wardrobes'
on conflict (category_id, key) do nothing;

insert into public.attribute_definitions
  (subcategory_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select s.id, 'opening_type', 'Eshik turi', 'Тип открывания', 'select', null, false, 5
from public.subcategories s
where s.name = 'Wardrobes'
on conflict (subcategory_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('swing',   'Oddiy',  'Распашной',   10),
  ('sliding', 'Kupé',   'Купе',        20)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'opening_type'
  and ad.subcategory_id = (select id from public.subcategories where name = 'Wardrobes')
on conflict (attribute_id, value) do nothing;

-- ============================================================
-- DECOR & ACCENTS (lightweight set — mostly free-form)
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('material',   'Material',        'Материал',  'text',   null::text, false, 10),
  ('weight_kg',  'Og''irligi',      'Вес',       'number', 'kg',        false, 20),
  ('width_cm',   'Eni',             'Ширина',    'number', 'sm',        false, 30),
  ('height_cm',  'Bo''yi',          'Высота',    'number', 'sm',        false, 40)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Decor & Accents'
on conflict (category_id, key) do nothing;

-- ============================================================
-- OUTDOOR LIVING
-- ============================================================

insert into public.attribute_definitions
  (category_id, key, label_uz, label_ru, data_type, unit, is_required, sort_order)
select c.id, v.key, v.label_uz, v.label_ru, v.data_type, v.unit, v.is_required, v.sort_order
from public.categories c
cross join (values
  ('outdoor_material', 'Material',      'Материал',         'select', null::text, true,  10),
  ('weatherproof',     'Suvga chidamli','Влагостойкий',     'bool',   null,        false, 20),
  ('width_cm',         'Eni',           'Ширина',           'number', 'sm',        false, 30),
  ('height_cm',        'Bo''yi',        'Высота',           'number', 'sm',        false, 40),
  ('depth_cm',         'Chuqurligi',    'Глубина',          'number', 'sm',        false, 50)
) as v(key, label_uz, label_ru, data_type, unit, is_required, sort_order)
where c.name = 'Outdoor Living'
on conflict (category_id, key) do nothing;

insert into public.attribute_options (attribute_id, value, label_uz, label_ru, sort_order)
select ad.id, v.value, v.label_uz, v.label_ru, v.sort_order
from public.attribute_definitions ad
cross join (values
  ('aluminum', 'Alyuminiy', 'Алюминий', 10),
  ('rattan',   'Ratan',     'Ротанг',   20),
  ('wood',     'Yog''och',  'Дерево',   30),
  ('plastic',  'Plastik',   'Пластик',  40),
  ('steel',    'Po''lat',   'Сталь',    50)
) as v(value, label_uz, label_ru, sort_order)
where ad.key = 'outdoor_material'
  and ad.category_id = (select id from public.categories where name = 'Outdoor Living')
on conflict (attribute_id, value) do nothing;
