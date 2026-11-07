-- SQL 18: entrega pelo motoboy do Pede Aki (loja de comissao com entrega_modo = 'app').
-- So ACRESCENTA tabelas e funcoes; mexe em duas funcoes do SQL 16 e 17 (pedido_pago e orders_formas_pagamento), que sao refeitas por inteiro.
-- Fluxo: pedido pago -> entrega PREVISTA (motoboy ve, nao pega) -> lojista aceita (Em Producao) -> DISPONIVEL -> motoboy pega ->
-- Retirei -> Cheguei -> digita o codigo do cliente -> ENTREGUE -> repasse do frete fica "pendente" para o Ikarus pagar.

create extension if not exists pgcrypto with schema extensions;

-- tempo de preparo por loja (o lojista define; padrao 20 minutos)
alter table public.stores add column if not exists tempo_preparo_min int not null default 20;

-- 1. Motoboys do Pede Aki (cadastrados pelo administrador; senha guardada em hash)
create table if not exists public.motoboys_app (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  telefone text not null unique,
  senha text not null,
  wallet_id text,
  ativo boolean not null default true,
  online boolean not null default false,
  online_em timestamptz,
  session_token text,
  falhas int not null default 0,
  bloqueado_ate timestamptz,
  criado_em timestamptz not null default now()
);
alter table public.motoboys_app enable row level security;
drop policy if exists motoboys_admin on public.motoboys_app;
create policy motoboys_admin on public.motoboys_app for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

create or replace function public.motoboys_app_prepara()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  new.telefone := public.fone_canonico(new.telefone);
  if tg_op = 'UPDATE' and (new.senha is null or new.senha = '') then
    new.senha := old.senha;
  end if;
  if new.senha is not null and new.senha <> '' and new.senha !~ '^\$2[aby]\$'
     and (tg_op = 'INSERT' or new.senha is distinct from old.senha) then
    new.senha := crypt(new.senha, gen_salt('bf'));
    new.session_token := null;
  end if;
  return new;
end $$;
drop trigger if exists motoboys_app_prepara on public.motoboys_app;
create trigger motoboys_app_prepara before insert or update on public.motoboys_app
  for each row execute function public.motoboys_app_prepara();

-- 2. Entregas (uma por pedido). O codigo fica aqui, numa tabela fechada: so o cliente (pelo telefone) e o administrador chegam nele.
create table if not exists public.entregas_app (
  id uuid primary key default gen_random_uuid(),
  order_id text not null unique,
  store_id uuid not null,
  motoboy_id uuid references public.motoboys_app(id),
  status text not null default 'prevista' check (status in ('prevista', 'disponivel', 'aceita', 'retirada', 'entregue', 'cancelada', 'frustrada')),
  frete numeric(12,2) not null default 0,
  codigo text not null,
  tentativas int not null default 0,
  bloqueada boolean not null default false,
  prazo_retirar timestamptz,
  prazo_entregar timestamptz,
  criada_em timestamptz not null default now(),
  disponivel_em timestamptz,
  aceita_em timestamptz,
  retirada_em timestamptz,
  chegou_em timestamptz,
  entregue_em timestamptz,
  cancelada_em timestamptz,
  motivo text
);
create index if not exists entregas_app_status_idx on public.entregas_app (status);
create index if not exists entregas_app_motoboy_idx on public.entregas_app (motoboy_id);
alter table public.entregas_app enable row level security;
drop policy if exists entregas_admin on public.entregas_app;
create policy entregas_admin on public.entregas_app for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- 3. Repasse do frete ao motoboy (o Ikarus paga e marca como pago)
create table if not exists public.repasses_motoboy (
  id uuid primary key default gen_random_uuid(),
  entrega_id uuid not null unique references public.entregas_app(id),
  motoboy_id uuid not null references public.motoboys_app(id),
  valor numeric(12,2) not null,
  status text not null default 'pendente' check (status in ('pendente', 'pago')),
  criado_em timestamptz not null default now(),
  pago_em timestamptz,
  observacao text
);
alter table public.repasses_motoboy enable row level security;
drop policy if exists repasses_admin on public.repasses_motoboy;
create policy repasses_admin on public.repasses_motoboy for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- 4. Aviso de eventos da entrega (cheguei, retirei...) para o Pede Aki mandar a mensagem ao cliente
create table if not exists public.entrega_eventos (
  id bigserial primary key,
  entrega_id uuid not null,
  order_id text not null,
  tipo text not null,
  criado_em timestamptz not null default now(),
  enviado boolean not null default false
);
alter table public.entrega_eventos enable row level security;
drop policy if exists eventos_admin on public.entrega_eventos;
create policy eventos_admin on public.entrega_eventos for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- 5. Codigo de 4 digitos aleatorio, sem relacao com o telefone, sem sequencia nem numero repetido
create or replace function public._codigo_entrega()
returns text language plpgsql volatile set search_path = public, extensions as $$
declare c text; b bytea;
begin
  loop
    b := gen_random_bytes(2);
    c := lpad(((get_byte(b, 0) * 256 + get_byte(b, 1)) % 10000)::text, 4, '0');
    exit when c !~ '^(\d)\1{3}$' and c not in ('0123', '1234', '2345', '3456', '4567', '5678', '6789', '3210', '4321', '5432', '6543', '7654', '8765', '9876');
  end loop;
  return c;
end $$;
revoke all on function public._codigo_entrega() from public, anon, authenticated;

-- 6. Pagamento confirmado: alem de virar Novo, cria a entrega (so loja com entrega pelo Pede Aki e pedido de Entrega)
create or replace function public.pedido_pago(p_order text, p_payment text)
returns text language plpgsql security definer set search_path = public as $$
declare o public.orders; v_modo text;
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

  select entrega_modo into v_modo from public.stores where id = o.store_id;
  if coalesce(v_modo, 'propria') = 'app' and o.order_type = 'Entrega' then
    insert into public.entregas_app (order_id, store_id, frete, codigo)
    values (o.id::text, o.store_id, coalesce(o.delivery_fee, 0), public._codigo_entrega())
    on conflict (order_id) do nothing;
  end if;
  return 'ok';
end $$;
revoke all on function public.pedido_pago(text, text) from public, anon, authenticated;

-- 7. Loja com entrega pelo Pede Aki: pedido de Entrega so com pagamento online (dinheiro so na Retirada)
create or replace function public.orders_formas_pagamento()
returns trigger language plpgsql security definer set search_path = public as $$
declare v record;
begin
  if new.origin is null or new.origin not in ('WEB', 'APP') then return new; end if;
  select modelo, pagamento_pix, pagamento_cartao, entrega_modo into v from public.stores where id = new.store_id;
  if not found or coalesce(v.modelo, 'pdv') <> 'comissao' then return new; end if;
  if new.payment_method = 'PIX' and coalesce(v.pagamento_pix, true) = false then
    raise exception 'Esta loja nao aceita PIX.';
  end if;
  if new.payment_method = 'Cartão' and coalesce(v.pagamento_cartao, false) = false then
    raise exception 'Esta loja nao aceita cartao.';
  end if;
  if coalesce(v.entrega_modo, 'propria') = 'app' and new.order_type = 'Entrega' and new.payment_method not in ('PIX', 'Cartão') then
    raise exception 'A entrega pelo Pede Aki so aceita pagamento online. Escolha PIX ou retire na loja.';
  end if;
  return new;
end $$;

-- 8. Quando o lojista aceita (Em Producao) a entrega fica disponivel; quando cancela, a entrega some
create or replace function public.orders_entrega_app()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_prep int;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status = 'Em Produção' then
    select coalesce(tempo_preparo_min, 20) into v_prep from public.stores where id = new.store_id;
    update public.entregas_app
       set status = 'disponivel', disponivel_em = now(),
           prazo_retirar = now() + make_interval(mins => coalesce(v_prep, 20)),
           prazo_entregar = now() + make_interval(mins => coalesce(v_prep, 20) + 20)
     where order_id = new.id::text and status = 'prevista';
  elsif new.status = 'Cancelado' then
    update public.entregas_app
       set status = 'cancelada', cancelada_em = now(), motivo = coalesce(new.cancel_reason, 'Pedido cancelado')
     where order_id = new.id::text and status in ('prevista', 'disponivel', 'aceita');
  end if;
  return new;
end $$;
drop trigger if exists orders_entrega_app on public.orders;
create trigger orders_entrega_app after update of status on public.orders
  for each row execute function public.orders_entrega_app();

-- 9. Entrega do Pede Aki: so o motoboy (ou o administrador) leva o pedido para A Caminho, No Portao e Entregue
create or replace function public.orders_guarda_entrega_app()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and new.status in ('A Caminho', 'No Portão', 'Entregue')
     and coalesce(current_setting('pedeaki.entrega', true), '') <> '1'
     and auth.uid() is not null and not public.is_platform_admin()
     and exists (select 1 from public.entregas_app where order_id = new.id::text and status <> 'cancelada') then
    raise exception 'Esta entrega e feita pelo motoboy do Pede Aki.';
  end if;
  return new;
end $$;
drop trigger if exists orders_guarda_entrega_app on public.orders;
create trigger orders_guarda_entrega_app before update of status on public.orders
  for each row execute function public.orders_guarda_entrega_app();

-- 10. Funcoes do cliente (pelo telefone do pedido)
create or replace function public.pedido_entrega(p_order text, p_phone text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e public.entregas_app; o record; v_nome text;
begin
  select id, phone, payment_status into o from public.orders
   where id::text = p_order and public.fone_canonico(phone) = public.fone_canonico(p_phone) limit 1;
  if not found or o.payment_status is distinct from 'pago' then return null; end if;
  select * into e from public.entregas_app where order_id = p_order;
  if not found then return jsonb_build_object('tem_entrega', false); end if;
  select nome into v_nome from public.motoboys_app where id = e.motoboy_id;
  return jsonb_build_object(
    'tem_entrega', true, 'status', e.status, 'bloqueada', e.bloqueada, 'motoboy', v_nome, 'frete', e.frete,
    'prazo_entregar', e.prazo_entregar,
    'codigo', case when e.status in ('prevista', 'disponivel', 'aceita', 'retirada') then e.codigo else null end);
end $$;
revoke all on function public.pedido_entrega(text, text) from public;
grant execute on function public.pedido_entrega(text, text) to anon, authenticated;

-- ha motoboy online agora? (o checkout so oferece Entrega Pede Aki se sim)
create or replace function public.entrega_app_disponivel()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.motoboys_app where ativo and online and online_em > now() - interval '3 minutes');
$$;
revoke all on function public.entrega_app_disponivel() from public;
grant execute on function public.entrega_app_disponivel() to anon, authenticated;

-- 11. Funcoes do motoboy (sessao por token, como o entregador das lojas)
create or replace function public._motoboy_valido(p_token text)
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.motoboys_app where p_token is not null and p_token <> '' and session_token = p_token and ativo limit 1;
$$;
revoke all on function public._motoboy_valido(text) from public, anon, authenticated;

create or replace function public.motoboy_login(p_telefone text, p_senha text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare m public.motoboys_app; v_tok text;
begin
  select * into m from public.motoboys_app where telefone = public.fone_canonico(p_telefone);
  if not found or not m.ativo then return jsonb_build_object('ok', false, 'erro', 'Telefone ou senha incorretos.'); end if;
  if m.bloqueado_ate is not null and m.bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'erro', 'Muitas tentativas. Tente de novo em alguns minutos.');
  end if;
  if m.senha = crypt(coalesce(p_senha, ''), m.senha) then
    v_tok := encode(gen_random_bytes(24), 'hex');
    update public.motoboys_app set session_token = v_tok, falhas = 0, bloqueado_ate = null where id = m.id;
    return jsonb_build_object('ok', true, 'token', v_tok, 'nome', m.nome);
  end if;
  update public.motoboys_app
     set falhas = case when falhas + 1 >= 5 then 0 else falhas + 1 end,
         bloqueado_ate = case when falhas + 1 >= 5 then now() + interval '15 minutes' else bloqueado_ate end
   where id = m.id;
  return jsonb_build_object('ok', false, 'erro', 'Telefone ou senha incorretos.');
end $$;
revoke all on function public.motoboy_login(text, text) from public;
grant execute on function public.motoboy_login(text, text) to anon, authenticated;

create or replace function public.motoboy_online(p_token text, p_online boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token);
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.motoboys_app set online = coalesce(p_online, false), online_em = now() where id = v_m;
  return jsonb_build_object('ok', true, 'online', coalesce(p_online, false));
end $$;
revoke all on function public.motoboy_online(text, boolean) from public;
grant execute on function public.motoboy_online(text, boolean) to anon, authenticated;

-- painel do motoboy: entregas dele, disponiveis, previstas e ganhos (cada chamada tambem marca "visto agora")
create or replace function public.motoboy_painel(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); m public.motoboys_app; r jsonb;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.motoboys_app set online_em = now() where id = v_m and online;
  select * into m from public.motoboys_app where id = v_m;
  r := jsonb_build_object(
    'ok', true, 'nome', m.nome, 'online', m.online,
    'ganhos_hoje', coalesce((select sum(valor) from public.repasses_motoboy where motoboy_id = v_m and criado_em >= date_trunc('day', now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'), 0),
    'a_receber', coalesce((select sum(valor) from public.repasses_motoboy where motoboy_id = v_m and status = 'pendente'), 0),
    'minhas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'status', e.status, 'frete', e.frete, 'loja', s.name,
        'loja_endereco', (select store_address from public.settings where store_id = e.store_id limit 1),
        'cliente', o.customer_name, 'endereco', o.address, 'referencia', o.reference_point,
        'prazo_retirar', e.prazo_retirar, 'prazo_entregar', e.prazo_entregar, 'tentativas', e.tentativas, 'bloqueada', e.bloqueada) order by e.criada_em)
      from public.entregas_app e join public.stores s on s.id = e.store_id join public.orders o on o.id::text = e.order_id
      where e.motoboy_id = v_m and e.status in ('aceita', 'retirada')), '[]'::jsonb),
    'disponiveis', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'status', e.status, 'frete', e.frete, 'loja', s.name,
        'loja_endereco', (select store_address from public.settings where store_id = e.store_id limit 1),
        'bairro', nullif(btrim(substring(o.address from 'Bairro: (.*)$')), ''),
        'prazo_retirar', e.prazo_retirar, 'prazo_entregar', e.prazo_entregar) order by e.criada_em)
      from public.entregas_app e join public.stores s on s.id = e.store_id join public.orders o on o.id::text = e.order_id
      where e.status = 'disponivel' and e.motoboy_id is null), '[]'::jsonb),
    'previstas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'status', e.status, 'frete', e.frete, 'loja', s.name,
        'bairro', nullif(btrim(substring(o.address from 'Bairro: (.*)$')), '')) order by e.criada_em)
      from public.entregas_app e join public.stores s on s.id = e.store_id join public.orders o on o.id::text = e.order_id
      where e.status = 'prevista' and e.criada_em > now() - interval '30 minutes'), '[]'::jsonb));
  return r;
end $$;
revoke all on function public.motoboy_painel(text) from public;
grant execute on function public.motoboy_painel(text) to anon, authenticated;

create or replace function public.motoboy_aceitar(p_token text, p_entrega uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app; v_nome text; v_ativas int;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  select count(*) into v_ativas from public.entregas_app where motoboy_id = v_m and status in ('aceita', 'retirada');
  if v_ativas >= 2 then return jsonb_build_object('ok', false, 'erro', 'Termine as entregas que voce ja pegou antes de pegar outra.'); end if;
  update public.entregas_app set status = 'aceita', motoboy_id = v_m, aceita_em = now()
   where id = p_entrega and status = 'disponivel' and motoboy_id is null returning * into e;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Outro motoboy pegou esta entrega.'); end if;
  select nome into v_nome from public.motoboys_app where id = v_m;
  update public.orders set courier_name = v_nome where id::text = e.order_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.motoboy_aceitar(text, uuid) from public;
grant execute on function public.motoboy_aceitar(text, uuid) to anon, authenticated;

create or replace function public.motoboy_soltar(p_token text, p_entrega uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.entregas_app set status = 'disponivel', motoboy_id = null, aceita_em = null
   where id = p_entrega and motoboy_id = v_m and status = 'aceita' returning * into e;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Nao foi possivel devolver esta entrega.'); end if;
  update public.orders set courier_name = null where id::text = e.order_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.motoboy_soltar(text, uuid) from public;
grant execute on function public.motoboy_soltar(text, uuid) to anon, authenticated;

create or replace function public.motoboy_retirei(p_token text, p_entrega uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.entregas_app set status = 'retirada', retirada_em = now()
   where id = p_entrega and motoboy_id = v_m and status = 'aceita' returning * into e;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Entrega nao encontrada.'); end if;
  perform set_config('pedeaki.entrega', '1', true);
  update public.orders
     set status = 'A Caminho',
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'A Caminho', 'timestamp', now()))
   where id::text = e.order_id;
  perform set_config('pedeaki.entrega', '', true);
  insert into public.entrega_eventos (entrega_id, order_id, tipo) values (e.id, e.order_id, 'retirou');
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.motoboy_retirei(text, uuid) from public;
grant execute on function public.motoboy_retirei(text, uuid) to anon, authenticated;

create or replace function public.motoboy_cheguei(p_token text, p_entrega uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.entregas_app set chegou_em = now()
   where id = p_entrega and motoboy_id = v_m and status = 'retirada' returning * into e;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Entrega nao encontrada.'); end if;
  perform set_config('pedeaki.entrega', '1', true);
  update public.orders
     set status = 'No Portão',
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'No Portão', 'timestamp', now()))
   where id::text = e.order_id;
  perform set_config('pedeaki.entrega', '', true);
  insert into public.entrega_eventos (entrega_id, order_id, tipo) values (e.id, e.order_id, 'chegou');
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.motoboy_cheguei(text, uuid) from public;
grant execute on function public.motoboy_cheguei(text, uuid) to anon, authenticated;

-- entrega: o motoboy digita o codigo que o cliente passou (3 erros bloqueiam; so o administrador libera com codigo novo)
create or replace function public.motoboy_entregar(p_token text, p_entrega uuid, p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app; v_t int;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  select * into e from public.entregas_app where id = p_entrega and motoboy_id = v_m and status = 'retirada' for update;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Entrega nao encontrada.'); end if;
  if e.bloqueada then return jsonb_build_object('ok', false, 'bloqueada', true, 'erro', 'Codigo bloqueado. Fale com o suporte do Pede Aki.'); end if;
  if btrim(coalesce(p_codigo, '')) = e.codigo then
    update public.entregas_app set status = 'entregue', entregue_em = now() where id = e.id;
    perform set_config('pedeaki.entrega', '1', true);
    update public.orders
       set status = 'Entregue',
           status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'Entregue', 'timestamp', now()))
     where id::text = e.order_id;
    perform set_config('pedeaki.entrega', '', true);
    insert into public.repasses_motoboy (entrega_id, motoboy_id, valor) values (e.id, v_m, e.frete) on conflict (entrega_id) do nothing;
    insert into public.entrega_eventos (entrega_id, order_id, tipo) values (e.id, e.order_id, 'entregue');
    return jsonb_build_object('ok', true, 'ganho', e.frete);
  end if;
  v_t := e.tentativas + 1;
  update public.entregas_app set tentativas = v_t, bloqueada = (v_t >= 3) where id = e.id;
  return jsonb_build_object('ok', false, 'bloqueada', v_t >= 3, 'restantes', greatest(0, 3 - v_t),
    'erro', case when v_t >= 3 then 'Codigo bloqueado. Fale com o suporte do Pede Aki.' else 'Codigo incorreto.' end);
end $$;
revoke all on function public.motoboy_entregar(text, uuid, text) from public;
grant execute on function public.motoboy_entregar(text, uuid, text) to anon, authenticated;

-- entrega frustrada (cliente ausente ou recusou): o motoboy recebe o frete; o suporte decide o resto
create or replace function public.motoboy_frustrada(p_token text, p_entrega uuid, p_motivo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m uuid := public._motoboy_valido(p_token); e public.entregas_app;
begin
  if v_m is null then return jsonb_build_object('ok', false, 'erro', 'Sessao expirada. Entre de novo.'); end if;
  update public.entregas_app set status = 'frustrada', cancelada_em = now(), motivo = left(coalesce(nullif(btrim(p_motivo), ''), 'Cliente nao recebeu'), 200)
   where id = p_entrega and motoboy_id = v_m and status = 'retirada' returning * into e;
  if not found then return jsonb_build_object('ok', false, 'erro', 'Entrega nao encontrada.'); end if;
  insert into public.repasses_motoboy (entrega_id, motoboy_id, valor, observacao) values (e.id, v_m, e.frete, 'Entrega frustrada: ' || e.motivo) on conflict (entrega_id) do nothing;
  insert into public.entrega_eventos (entrega_id, order_id, tipo) values (e.id, e.order_id, 'frustrada');
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.motoboy_frustrada(text, uuid, text) from public;
grant execute on function public.motoboy_frustrada(text, uuid, text) to anon, authenticated;

-- 12. Administrador: codigo novo para o cliente (zera as tentativas e desbloqueia)
create or replace function public.entrega_novo_codigo(p_entrega uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Somente o administrador da plataforma.'; end if;
  update public.entregas_app set codigo = public._codigo_entrega(), tentativas = 0, bloqueada = false
   where id = p_entrega and status in ('prevista', 'disponivel', 'aceita', 'retirada');
end $$;
revoke all on function public.entrega_novo_codigo(uuid) from public;
grant execute on function public.entrega_novo_codigo(uuid) to authenticated;
