-- SQL 17: controles por loja (so o administrador da plataforma muda): formas de pagamento e quem faz a entrega.
-- So ACRESCENTA colunas e gatilhos. Loja sem mudanca continua como estava: PIX ligado, cartao online desligado, entrega propria.

alter table public.stores add column if not exists pagamento_pix boolean not null default true;
alter table public.stores add column if not exists pagamento_cartao boolean not null default false;
alter table public.stores add column if not exists entrega_modo text not null default 'propria';
alter table public.stores drop constraint if exists stores_entrega_modo_check;
alter table public.stores add constraint stores_entrega_modo_check check (entrega_modo in ('propria', 'app'));

-- 1. O lojista nao pode ligar nem desligar estes controles da propria loja (so o administrador da plataforma;
--    pelo editor de SQL do Supabase, sem login de usuario, continua podendo).
create or replace function public.stores_protege_controles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_platform_admin() and (
        new.entrega_modo is distinct from old.entrega_modo
     or new.pagamento_pix is distinct from old.pagamento_pix
     or new.pagamento_cartao is distinct from old.pagamento_cartao) then
    raise exception 'Somente o administrador da plataforma altera estes controles.';
  end if;
  return new;
end $$;
drop trigger if exists stores_protege_controles on public.stores;
create trigger stores_protege_controles before update on public.stores
  for each row execute function public.stores_protege_controles();

-- 2. O servidor tambem recusa a forma de pagamento desligada (quem chamar a funcao direto nao passa por cima da tela)
create or replace function public.orders_formas_pagamento()
returns trigger language plpgsql security definer set search_path = public as $$
declare v record;
begin
  if new.origin is null or new.origin not in ('WEB', 'APP') then return new; end if;
  select modelo, pagamento_pix, pagamento_cartao into v from public.stores where id = new.store_id;
  if not found or coalesce(v.modelo, 'pdv') <> 'comissao' then return new; end if;
  if new.payment_method = 'PIX' and coalesce(v.pagamento_pix, true) = false then
    raise exception 'Esta loja nao aceita PIX.';
  end if;
  if new.payment_method = 'Cartão' and coalesce(v.pagamento_cartao, false) = false then
    raise exception 'Esta loja nao aceita cartao.';
  end if;
  return new;
end $$;
drop trigger if exists orders_formas_pagamento on public.orders;
create trigger orders_formas_pagamento before insert on public.orders
  for each row execute function public.orders_formas_pagamento();
