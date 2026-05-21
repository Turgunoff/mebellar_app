-- Delivery fee adjustment feature.
--
-- Seller can propose a new delivery fee on an order; the customer
-- confirms or rejects it. The order stays visible (no status change)
-- while the proposal is pending.
--
-- New columns on public.orders:
--   proposed_delivery_fee  -- what the seller wants to charge
--   fee_adjustment_note    -- optional explanation for the customer
--   fee_adjustment_status  -- 'pending_customer' | 'approved' | 'rejected'
--
-- Two trigger-driven notifications mirror the existing
-- notify_seller_on_order_item_insert() pattern.

-- ── 1. Schema ───────────────────────────────────────────────────────────────

alter table public.orders
  add column if not exists proposed_delivery_fee numeric,
  add column if not exists fee_adjustment_note   text,
  add column if not exists fee_adjustment_status text
    check (fee_adjustment_status in ('pending_customer', 'approved', 'rejected'));

-- ── 2. Notify customer when seller proposes a fee ───────────────────────────

create or replace function notify_customer_on_fee_proposal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Fire only when fee_adjustment_status just became 'pending_customer'.
  if new.fee_adjustment_status = 'pending_customer'
     and (old.fee_adjustment_status is distinct from 'pending_customer') then

    insert into notifications (user_id, title, body, type, reference_id, data)
    values (
      new.user_id,
      'Yetkazish narxi o''zgardi 🚚',
      'Sotuvchi yetkazish narxini '
        || to_char(new.proposed_delivery_fee, 'FM999,999,999')
        || ' UZS ga o''zgartirdi. Tasdiqlaysizmi?',
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

drop trigger if exists orders_notify_fee_proposal on public.orders;
create trigger orders_notify_fee_proposal
  after update on public.orders
  for each row
  execute function notify_customer_on_fee_proposal();

-- ── 3. Notify seller when customer responds ─────────────────────────────────

create or replace function notify_seller_on_fee_response()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_user_id uuid;
  v_body           text;
begin
  -- Fire only when status just became 'approved' or 'rejected'.
  if new.fee_adjustment_status in ('approved', 'rejected')
     and old.fee_adjustment_status = 'pending_customer' then

    select s.seller_id into v_seller_user_id
    from order_items oi
    join products  p on p.id  = oi.product_id
    join shops     s on s.id  = p.shop_id
    where oi.order_id = new.id
    limit 1;

    if v_seller_user_id is null then
      return new;
    end if;

    v_body := case new.fee_adjustment_status
      when 'approved' then 'Mijoz yangi yetkazish narxini tasdiqladi ✅'
      else                 'Mijoz yangi yetkazish narxini rad etdi ❌'
    end;

    insert into notifications (user_id, title, body, type, reference_id, data)
    values (
      v_seller_user_id,
      'Yetkazish narxi javobi',
      v_body,
      'fee_adjustment_response',
      new.id,
      jsonb_build_object(
        'mode',     'seller',
        'route',    '/seller/orders/' || new.id::text,
        'order_id', new.id::text
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists orders_notify_fee_response on public.orders;
create trigger orders_notify_fee_response
  after update on public.orders
  for each row
  execute function notify_seller_on_fee_response();
