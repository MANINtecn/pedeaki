-- SQL 16: base do pagamento online (Asaas). So ACRESCENTA colunas, tabelas e funcoes; nao muda nenhuma politica.
-- Pedido online nasce "Aguardando pagamento" e so vira "Novo" (e avisa o lojista) quando o pagamento confirma.
-- Quem confirma e a funcao da Vercel (chave de servico); o cliente nunca marca o proprio pedido como pago.

-- 1. Wallet do lojista no Asaas (tabela privada de condicoes financeiras)
alter table public.loja_financeiro add column if not exists asaas_wallet_id text;

-- 2. Colunas de pagamento no pedido
alter table public.orders add column if not exists payment_status text;      -- aguardando, pago, expirado, estornado (nulo = pagamento na entrega)
alter table public.orders add column if not exists asaas_payment_id text;
alter table public.orders add column if not exists pagar_ate timestamptz;
alter table public.orders add column if not exists pago_em timestamptz;
alter table public.orders drop constraint if exists orders_status_check;    -- novos estados: Aguardando pagamento e Expirado

-- 3. Pagamentos (so a chave de servico le e grava: RLS ligada e sem politica)
create table if not exists public.pagamentos (
  id uuid primary key default gen_random_uuid(),
  order_id text not null,
  store_id uuid not null,
  asaas_payment_id text unique,
  meio text not null default 'PIX',
  valor numeric(12,2) not null,
  comissao numeric(12,2) not null default 0,
  taxa_estimada numeric(12,2) not null default 0,
  repasse_lojista numeric(12,2) not null default 0,
  status text not null default 'PENDENTE',
  pix_copia_cola text,
  criado_em timestamptz not null default now(),
  pago_em timestamptz,
  atualizado_em timestamptz not null default now()
);
create index if not exists pagamentos_order_idx on public.pagamentos (order_id);
alter table public.pagamentos enable row level security;

-- 4. Eventos que o Asaas envia (idempotencia e alertas de split bloqueado ou recusado)
create table if not exists public.asaas_eventos (
  id text primary key,
  tipo text not null,
  payment_id text,
  order_id text,
  dados jsonb,
  recebido_em timestamptz not null default now(),
  tratado boolean not null default false
);
alter table public.asaas_eventos enable row level security;

-- 5. Pedido online nasce aguardando pagamento (o gatilho roda ANTES do insert, entao o aviso de pedido novo nao dispara)
create or replace function public.orders_pedido_online()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('pedeaki.online', true), '') = '1' and new.origin in ('WEB', 'APP') then
    new.status := 'Aguardando pagamento';
    new.payment_status := 'aguardando';
    new.pagar_ate := now() + interval '15 minutes';
    new.status_history := jsonb_build_array(jsonb_build_object('status', 'Aguardando pagamento', 'timestamp', now()));
  end if;
  return new;
end $$;
drop trigger if exists orders_pedido_online on public.orders;
create trigger orders_pedido_online before insert on public.orders
  for each row execute function public.orders_pedido_online();

-- 6. Criar pedido online: usa a mesma funcao de sempre (validacao de preco, frete, total), so marca como online
create or replace function public.criar_pedido_online(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_store uuid := nullif(p->>'store_id', '')::uuid; v_fin record; r jsonb;
begin
  if v_store is null then raise exception 'Loja invalida.'; end if;
  select * into v_fin from public.loja_financeiro where store_id = v_store;
  if not found or coalesce(v_fin.asaas_wallet_id, '') = '' then
    raise exception 'Esta loja ainda nao aceita pagamento online.';
  end if;
  if coalesce(p->>'payment_method', '') <> 'PIX' then raise exception 'Pagamento online so por PIX.'; end if;
  perform set_config('pedeaki.online', '1', true);
  r := public.criar_pedido_publico(p);
  perform set_config('pedeaki.online', '', true);
  return r;
end $$;
revoke all on function public.criar_pedido_online(jsonb) from public;
grant execute on function public.criar_pedido_online(jsonb) to anon, authenticated;

-- 7. Status do pedido para a tela do cliente (confere o telefone)
create or replace function public.pedido_status(p_order text, p_phone text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare o record;
begin
  select id, status, payment_status, pagar_ate into o from public.orders
   where id::text = p_order and public.fone_canonico(phone) = public.fone_canonico(p_phone) limit 1;
  if not found then return null; end if;
  return jsonb_build_object('status', o.status, 'payment_status', o.payment_status, 'pagar_ate', o.pagar_ate);
end $$;
revoke all on function public.pedido_status(text, text) from public;
grant execute on function public.pedido_status(text, text) to anon, authenticated;

-- 8. Pagamento confirmado (so a funcao da Vercel, com a chave de servico, chama)
create or replace function public.pedido_pago(p_order text, p_payment text)
returns text language plpgsql security definer set search_path = public as $$
declare o public.orders;
begin
  select * into o from public.orders where id::text = p_order for update;
  if not found then return 'nao_encontrado'; end if;
  if o.payment_status = 'pago' then return 'ja_pago'; end if;
  if o.status in ('Expirado', 'Cancelado') then
    update public.orders set payment_status = 'pago_apos_vencer', asaas_payment_id = p_payment where id = o.id;
    update public.pagamentos set status = 'PAGO_APOS_VENCER', pago_em = now(), atualizado_em = now() where asaas_payment_id = p_payment;
    return 'estornar';
  end if;
  update public.orders
     set status = 'Novo', payment_status = 'pago', pago_em = now(), asaas_payment_id = p_payment,
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'Novo', 'timestamp', now()))
   where id = o.id;
  update public.pagamentos set status = 'PAGO', pago_em = now(), atualizado_em = now() where asaas_payment_id = p_payment;
  return 'ok';
end $$;
revoke all on function public.pedido_pago(text, text) from public, anon, authenticated;

-- 9. Aviso ao lojista: no insert (pedido comum) e quando o pedido online passa de Aguardando pagamento para Novo
create or replace function public.orders_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_seg text;
begin
  if tg_op = 'UPDATE' and not (old.status = 'Aguardando pagamento' and new.status = 'Novo') then return new; end if;
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
  return new;
end $$;
drop trigger if exists orders_push_pago on public.orders;
create trigger orders_push_pago after update of status on public.orders
  for each row execute function public.orders_push();

-- 10. Freio de pedidos: pedido aguardando pagamento ou vencido nao conta para o limite da loja nem o "pedido identico",
--     mas cada telefone so pode ter 5 pedidos aguardando em 10 minutos (evita encher o banco)
create or replace function public.orders_freio_site()
returns trigger language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if new.origin is null or new.origin not in ('WEB', 'APP') then return new; end if;
  perform pg_advisory_xact_lock(hashtext('freio:' || new.store_id::text));
  if new.phone is not null then
    if exists (select 1 from public.orders where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP')
                  and status not in ('Aguardando pagamento', 'Expirado')
                  and total = new.total and items = new.items and timestamp > now() - interval '5 minutes') then
      raise exception 'Este pedido ja foi enviado.';
    end if;
    if exists (select 1 from public.orders where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP')
                  and status not in ('Aguardando pagamento', 'Expirado')
                  and timestamp > now() - interval '1 minute') then
      raise exception 'Aguarde 1 minuto para fazer outro pedido.';
    end if;
    select count(*) into v from public.orders
     where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP')
       and status not in ('Aguardando pagamento', 'Expirado') and timestamp > now() - interval '10 minutes';
    if v >= 3 then raise exception 'Muitos pedidos em pouco tempo. Aguarde alguns minutos.'; end if;
    select count(*) into v from public.orders
     where store_id = new.store_id and phone = new.phone and status = 'Aguardando pagamento' and timestamp > now() - interval '10 minutes';
    if v >= 5 then raise exception 'Muitas tentativas de pagamento. Aguarde alguns minutos.'; end if;
  end if;
  select count(*) into v from public.orders
   where store_id = new.store_id and origin in ('WEB', 'APP')
     and status not in ('Aguardando pagamento', 'Expirado') and timestamp > now() - interval '10 minutes';
  if v >= 60 then raise exception 'A loja esta com muitos pedidos agora. Tente em instantes.'; end if;
  return new;
end $$;

-- 11. Vencimento: pedido online nao pago em 15 minutos vira Expirado (roda a cada minuto)
create or replace function public.expirar_pedidos_online()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.orders
     set status = 'Expirado', payment_status = 'expirado',
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'Expirado', 'timestamp', now()))
   where status = 'Aguardando pagamento' and pagar_ate is not null and pagar_ate < now();
end $$;
revoke all on function public.expirar_pedidos_online() from public, anon, authenticated;

do $$ begin
  perform cron.unschedule('expirar-pedidos-online');
exception when others then null;
end $$;
select cron.schedule('expirar-pedidos-online', '* * * * *', 'select public.expirar_pedidos_online()');
