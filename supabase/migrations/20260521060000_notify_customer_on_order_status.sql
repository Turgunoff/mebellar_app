-- Customer-ga buyurtma holati o'zgarganda push notification yuborish.
--
-- Zanjir:
--   orders UPDATE (status o'zgardi)
--   → notify_customer_on_order_status_change()
--   → notifications INSERT (type=order / order_shipped / order_delivered)
--   → notifications_send_push trigger (mavjud)
--   → send-personal-push Edge Function
--   → FCM push to customer's devices
--
-- Faqat seller boshqaradigan oldinga siljishlar uchun ishlaydi:
--   confirmed · preparing · shipped · delivered.
-- 'cancelled' bu yerda qoldirilmadi — uni mijozning o'zi ham qilishi
-- mumkin, trigger esa kim bekor qilganini ajrata olmaydi.

create or replace function notify_customer_on_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_num text;
  v_title     text;
  v_body      text;
begin
  -- Faqat status haqiqatan o'zgarganda davom etamiz.
  if new.status is not distinct from old.status then
    return new;
  end if;

  v_order_num := 'M-' || upper(substring(new.id::text from 1 for 8));

  -- Mijozga ko'rinadigan har bir holat uchun matn. Boshqa holatlarda
  -- (masalan 'cancelled' yoki 'pending') notification yuborilmaydi.
  case new.status
    when 'confirmed' then
      v_title := 'Buyurtma qabul qilindi ✅';
      v_body  := v_order_num || ' raqamli buyurtmangiz sotuvchi tomonidan qabul qilindi.';
    when 'preparing' then
      v_title := 'Buyurtma tayyorlanmoqda 📦';
      v_body  := v_order_num || ' raqamli buyurtmangiz tayyorlanishni boshladi.';
    when 'shipped' then
      v_title := 'Buyurtma yo''lda 🚚';
      v_body  := v_order_num || ' raqamli buyurtmangiz yetkazib berish uchun yo''lga chiqdi.';
    when 'delivered' then
      v_title := 'Buyurtma yetkazildi 🎉';
      v_body  := v_order_num || ' raqamli buyurtmangiz manzilingizga yetkazib berildi.';
    else
      return new;
  end case;

  insert into notifications (user_id, title, body, type, reference_id, data)
  values (
    new.user_id,
    v_title,
    v_body,
    case new.status
      when 'shipped'   then 'order_shipped'
      when 'delivered' then 'order_delivered'
      else                  'order'
    end,
    new.id,
    jsonb_build_object(
      'mode',     'customer',
      'route',    '/orders/' || new.id::text,
      'order_id', new.id::text
    )
  );

  return new;
end;
$$;

drop trigger if exists orders_notify_customer_status on public.orders;
create trigger orders_notify_customer_status
  after update on public.orders
  for each row
  execute function notify_customer_on_order_status_change();
