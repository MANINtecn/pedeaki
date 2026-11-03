-- SQL 14: aviso de pedido novo com o celular bloqueado (Web Push).
-- Fluxo: pedido novo do site -> gatilho -> pg_net chama https://pedeaki.tecx.pro/api/push-pedido (com o segredo)
-- -> a funcao da Vercel pede as assinaturas ao banco (push_para_pedido) e manda o aviso.
-- Enquanto o pedido seguir "Novo", a rotina push_lembretes repete o aviso a cada minuto (ate 10 vezes).

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- segredo compartilhado entre o banco e a funcao da Vercel (ninguem le pela chave publica)
create table if not exists public.plataforma_segredos (nome text primary key, valor text not null);
alter table public.plataforma_segredos enable row level security;
revoke all on public.plataforma_segredos from anon, authenticated;
insert into public.plataforma_segredos (nome, valor)
values ('push', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (nome) do nothing;

-- aparelhos do lojista que ligaram o aviso
create table if not exists public.push_assinaturas (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  dispositivo text,
  criado_em timestamptz default now()
);
alter table public.push_assinaturas enable row level security;
revoke all on public.push_assinaturas from anon, authenticated;

alter table public.orders add column if not exists push_avisos int default 0;

-- o app do lojista registra o aparelho (so o dono da loja)
create or replace function public.push_registrar(p_store uuid, p_endpoint text, p_p256dh text, p_auth text, p_dispositivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.owns_store(p_store) then raise exception 'sem permissao nesta loja'; end if;
  if coalesce(p_endpoint, '') = '' or coalesce(p_p256dh, '') = '' or coalesce(p_auth, '') = '' then raise exception 'assinatura invalida'; end if;
  insert into public.push_assinaturas (store_id, endpoint, p256dh, auth, dispositivo)
  values (p_store, p_endpoint, p_p256dh, p_auth, left(p_dispositivo, 200))
  on conflict (endpoint) do update set store_id = excluded.store_id, p256dh = excluded.p256dh, auth = excluded.auth, dispositivo = excluded.dispositivo;
end $$;
revoke all on function public.push_registrar(uuid, text, text, text, text) from public, anon;
grant execute on function public.push_registrar(uuid, text, text, text, text) to authenticated;

-- a funcao da Vercel pede o que precisa para avisar (so com o segredo)
create or replace function public.push_para_pedido(p_order uuid, p_segredo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_seg text; o record; s record; v_subs jsonb;
begin
  select valor into v_seg from public.plataforma_segredos where nome = 'push';
  if v_seg is null or p_segredo is distinct from v_seg then raise exception 'negado'; end if;
  select id, store_id, status, daily_order_number, total, order_type into o from public.orders where id = p_order;
  if not found or o.status is distinct from 'Novo' then return jsonb_build_object('enviar', false); end if;
  select slug, name into s from public.stores where id = o.store_id;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'endpoint', endpoint, 'p256dh', p256dh, 'auth', auth)), '[]'::jsonb)
    into v_subs from public.push_assinaturas where store_id = o.store_id;
  return jsonb_build_object('enviar', true, 'slug', s.slug, 'loja', s.name, 'numero', o.daily_order_number,
                            'total', o.total, 'tipo', o.order_type, 'subs', v_subs);
end $$;
revoke all on function public.push_para_pedido(uuid, text) from public;
grant execute on function public.push_para_pedido(uuid, text) to anon, authenticated;

-- aparelho que cancelou o aviso: a funcao da Vercel tira da lista
create or replace function public.push_remover(p_ids uuid[], p_segredo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_seg text;
begin
  select valor into v_seg from public.plataforma_segredos where nome = 'push';
  if v_seg is null or p_segredo is distinct from v_seg then raise exception 'negado'; end if;
  delete from public.push_assinaturas where id = any(p_ids);
end $$;
revoke all on function public.push_remover(uuid[], text) from public;
grant execute on function public.push_remover(uuid[], text) to anon, authenticated;

-- gatilho: pedido novo vindo do site ou do app do cliente
create or replace function public.orders_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_seg text;
begin
  if new.origin is null or new.origin not in ('WEB', 'APP') or new.status is distinct from 'Novo' then return new; end if;
  if not exists (select 1 from public.push_assinaturas where store_id = new.store_id) then return new; end if;
  select valor into v_seg from public.plataforma_segredos where nome = 'push';
  if v_seg is null then return new; end if;
  perform net.http_post(
    url := 'https://pedeaki.tecx.pro/api/push-pedido',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-segredo', v_seg),
    body := jsonb_build_object('order_id', new.id),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  return new; -- o aviso nunca pode impedir o pedido de entrar
end $$;
drop trigger if exists orders_push on public.orders;
create trigger orders_push after insert on public.orders
  for each row execute function public.orders_push();

-- lembrete: pedido ainda "Novo" depois de 1 minuto avisa de novo, a cada minuto, ate 10 vezes
create or replace function public.push_lembretes()
returns void language plpgsql security definer set search_path = public as $$
declare r record; v_seg text;
begin
  select valor into v_seg from public.plataforma_segredos where nome = 'push';
  if v_seg is null then return; end if;
  for r in
    select o.id from public.orders o
     where o.status = 'Novo' and o.origin in ('WEB', 'APP')
       and o.timestamp < now() - interval '1 minute' and o.timestamp > now() - interval '30 minutes'
       and coalesce(o.push_avisos, 0) < 10
       and exists (select 1 from public.push_assinaturas p where p.store_id = o.store_id)
  loop
    update public.orders set push_avisos = coalesce(push_avisos, 0) + 1 where id = r.id;
    perform net.http_post(
      url := 'https://pedeaki.tecx.pro/api/push-pedido',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-segredo', v_seg),
      body := jsonb_build_object('order_id', r.id, 'lembrete', true),
      timeout_milliseconds := 5000
    );
  end loop;
exception when others then
  null;
end $$;
revoke all on function public.push_lembretes() from public, anon, authenticated;

do $$ begin
  perform cron.unschedule('push-lembretes');
exception when others then null;
end $$;
select cron.schedule('push-lembretes', '* * * * *', 'select public.push_lembretes()');

-- copie este valor para a Vercel (variavel PUSH_SEGREDO). Nao cole em chat nem no git.
select valor as push_segredo from public.plataforma_segredos where nome = 'push';
