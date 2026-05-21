-- Add fee_adjustment_proposed and fee_adjustment_response to the
-- notifications type allowlist, and fix the fee format in the trigger
-- to use spaces (Uzbek style) instead of commas.

-- 1. Extend the check constraint
alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'order', 'order_created', 'order_shipped', 'order_delivered',
    'price_drop', 'support_reply', 'news', 'promo', 'review',
    'system_alert', 'seller_approved', 'seller_rejected',
    'seller_new_order', 'seller_order_cancelled',
    'seller_product_approved', 'seller_product_rejected',
    'seller_low_stock', 'general',
    'fee_adjustment_proposed', 'fee_adjustment_response'
  ]));

-- 2. Fix the customer-notification trigger (space format, not commas)
create or replace function notify_customer_on_fee_proposal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_formatted text;
begin
  if new.fee_adjustment_status = 'pending_customer'
     and (old.fee_adjustment_status is distinct from 'pending_customer') then

    select replace(
      to_char(new.proposed_delivery_fee, 'FM999,999,999,999'),
      ',', ' '
    ) into v_formatted;

    insert into notifications (user_id, title, body, type, reference_id, data)
    values (
      new.user_id,
      'Yetkazish narxi o''zgardi 🚚',
      'Sotuvchi yetkazish narxini ' || v_formatted || ' UZS ga o''zgartirdi. Tasdiqlaysizmi?',
      'fee_adjustment_proposed',
      new.id,
      jsonb_build_object(
        'mode',     'customer',
        'route',    '/orders/' || new.id::text,
        'order_id', new.id::text
      )
    );
  end if;
  return new;
end;
$$;
