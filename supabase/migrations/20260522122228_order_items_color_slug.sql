-- Records the colour the customer chose at checkout, one slug per ordered
-- line. Nullable: products without a colour palette — and historic rows —
-- carry none. The value is a slug from the app's canonical colour palette
-- (white / black / grey / brown / beige / green / blue / yellow).
alter table public.order_items
  add column if not exists color_slug text;
