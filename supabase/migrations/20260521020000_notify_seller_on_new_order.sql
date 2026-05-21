-- Seller-ga yangi buyurtma push notification yuborish.
--
-- Zanjir:
--   order_items INSERT
--   → notify_seller_on_order_item_insert()
--   → notifications INSERT (type=seller_new_order)
--   → notifications_send_push trigger (mavjud)
--   → send-personal-push Edge Function
--   → FCM push to seller's devices
--
-- Dedup: bir order + bir do'kon juftligi uchun faqat bitta notification
-- (ko'p mahsulotli orderlarda takrorlanmaydi).
-- Multi-shop: turli do'konlardan mahsulot bo'lsa, har bir do'kon egasiga
-- alohida notification yuboriladi.

create or replace function notify_seller_on_order_item_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_user_id uuid;
  v_shop_id        uuid;
  v_order_amount   numeric;
  v_buyer_name     text;
begin
  -- Mahsulot qaysi do'konga tegishli
  select p.shop_id into v_shop_id
  from products p
  where p.id = new.product_id;

  if v_shop_id is null then
    return new;
  end if;

  -- Do'kon egasining auth user_id-si (shops.seller_id = sellers.id = auth.users.id)
  select s.seller_id into v_seller_user_id
  from shops s
  where s.id = v_shop_id;

  if v_seller_user_id is null then
    return new;
  end if;

  -- Dedup: bu order+seller juftligi uchun allaqachon notification bormi?
  if exists (
    select 1
    from notifications
    where user_id     = v_seller_user_id
      and reference_id = new.order_id
      and type        = 'seller_new_order'
  ) then
    return new;
  end if;

  -- Order summasi va xaridor ismi
  select o.total_amount into v_order_amount
  from orders o
  where o.id = new.order_id;

  select coalesce(pr.full_name, 'Mijoz') into v_buyer_name
  from orders o
  left join profiles pr on pr.id = o.user_id
  where o.id = new.order_id;

  -- Notification yaratish (notifications_send_push trigger → FCM-ni ishga tushiradi)
  insert into notifications (user_id, title, body, type, reference_id, data)
  values (
    v_seller_user_id,
    'Yangi buyurtma! 🛍',
    v_buyer_name || ' — ' || to_char(v_order_amount, 'FM999,999,999') || ' UZS',
    'seller_new_order',
    new.order_id,
    jsonb_build_object(
      'mode',     'seller',
      'route',    '/seller/orders/' || new.order_id::text,
      'order_id', new.order_id::text
    )
  );

  return new;
end;
$$;

-- Trigger: har bir order_items INSERT-dan keyin yuqoridagi funksiya chaqiriladi
drop trigger if exists order_items_notify_seller on order_items;
create trigger order_items_notify_seller
  after insert on order_items
  for each row
  execute function notify_seller_on_order_item_insert();
