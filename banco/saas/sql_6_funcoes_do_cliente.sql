-- SQL 6: funcoes do cliente do site (Rodada 1, parte 2). So ACRESCENTA funcoes; nao muda nenhuma politica.
-- Depois desta, o site passa a usar estas funcoes em vez de ler/gravar direto nas tabelas.

create or replace function public.fone_canonico(p text, p_ddd text default '32')
returns text language plpgsql immutable as $$
declare d text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
begin
  if left(d, 2) = '55' and length(d) in (12, 13) then d := substr(d, 3); end if;
  if length(d) <= 8 then return p_ddd || right(d, 8); end if;
  if length(d) - 8 >= 2 then return left(d, 2) || right(d, 8); end if;
  return p_ddd || right(d, 8);
end $$;

-- 1. Cadastro do cliente pelo telefone (aceita as variantes com e sem o 9)
create or replace function public.cliente_por_telefone(p_store uuid, p_phones text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if p_store is null or p_phones is null or array_length(p_phones, 1) is null or array_length(p_phones, 1) > 4 then return null; end if;
  select to_jsonb(c) into v from public.customers c
   where c.store_id = p_store and c.phone = any(p_phones)
   order by c.created_at desc limit 1;
  return v;
end $$;

-- 2. Salvar o cliente (so nome, endereco e referencia; contadores sao do servidor)
create or replace function public.salvar_cliente(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_store uuid := nullif(p->>'store_id', '')::uuid;
  v_fone  text := public.fone_canonico(p->>'phone');
  v_row   public.customers;
begin
  if v_store is null or not exists (select 1 from public.stores where id = v_store and coalesce(is_active, false)) then
    raise exception 'Loja indisponivel';
  end if;
  if length(v_fone) <> 10 then raise exception 'Telefone invalido'; end if;
  insert into public.customers (store_id, phone, name, address, reference_point)
  values (v_store, v_fone, left(coalesce(p->>'name', ''), 120), left(p->>'address', 300), left(p->>'reference_point', 200))
  on conflict (phone, store_id) do update set
    name = case when p ? 'name' and nullif(p->>'name', '') is not null then excluded.name else public.customers.name end,
    address = case when p ? 'address' then excluded.address else public.customers.address end,
    reference_point = case when p ? 'reference_point' then excluded.reference_point else public.customers.reference_point end
  returning * into v_row;
  return to_jsonb(v_row);
end $$;

-- 3. Ultimo pedido do cliente (pelo final do telefone)
create or replace function public.ultimo_pedido_por_telefone(p_store uuid, p_sufixo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_suf text := regexp_replace(coalesce(p_sufixo, ''), '\D', '', 'g'); v jsonb;
begin
  if p_store is null or length(v_suf) < 8 then return null; end if;
  select to_jsonb(o) into v from public.orders o
   where o.store_id = p_store and o.phone ilike '%' || v_suf
   order by o.timestamp desc limit 1;
  return v;
end $$;

-- 4. Avaliar o pedido
create or replace function public.avaliar_pedido(p_id uuid, p_rating int, p_feedback text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if p_rating is null or p_rating < 1 or p_rating > 5 then raise exception 'Nota invalida'; end if;
  update public.orders set rating = p_rating, feedback = left(p_feedback, 500)
   where id = p_id returning to_jsonb(orders) into v;
  return v;
end $$;

-- 5. Fidelidade por SELOS: pedidos que contam e resgate dos 10 mais antigos
create or replace function public.selos_do_cliente(p_store uuid, p_sufixo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_suf text := regexp_replace(coalesce(p_sufixo, ''), '\D', '', 'g'); v jsonb;
begin
  if p_store is null or length(v_suf) < 8 then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(to_jsonb(o) order by o.timestamp asc), '[]'::jsonb) into v
    from public.orders o
   where o.store_id = p_store and o.phone ilike '%' || v_suf
     and o.is_loyalty_eligible = true and o.origin in ('WEB', 'APP')
     and o.status <> 'Cancelado' and o.loyalty_redeemed_at is null;
  return v;
end $$;

create or replace function public.resgatar_selos(p_store uuid, p_sufixo text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_suf text := regexp_replace(coalesce(p_sufixo, ''), '\D', '', 'g'); v_ids uuid[];
begin
  if p_store is null or length(v_suf) < 8 then raise exception 'Telefone invalido'; end if;
  select array_agg(id) into v_ids from (
    select id from public.orders
     where store_id = p_store and phone ilike '%' || v_suf
       and is_loyalty_eligible = true and status = 'Entregue' and loyalty_redeemed_at is null
     order by timestamp asc limit 10 for update) s;
  if coalesce(array_length(v_ids, 1), 0) < 10 then
    raise exception 'Saldo insuficiente de selos para resgate (minimo 10).';
  end if;
  update public.orders set loyalty_redeemed_at = now() where id = any(v_ids);
  return true;
end $$;

-- 6. Fidelidade por PONTOS
create or replace function public._sincronizar_saldo(p_store uuid, p_canon text)
returns void language plpgsql security definer set search_path = public as $$
declare v_nove text := left(p_canon, 2) || '9' || substr(p_canon, 3); v_saldo numeric;
begin
  select greatest(0, coalesce(sum(points), 0)) into v_saldo from public.loyalty_points_ledger
   where store_id = p_store and phone in (p_canon, v_nove);
  insert into public.customer_loyalty_points (store_id, phone, points_balance, updated_at)
  values (p_store, p_canon, v_saldo, now())
  on conflict (store_id, phone) do update set points_balance = excluded.points_balance, updated_at = now();
  delete from public.customer_loyalty_points where store_id = p_store and phone = v_nove;
end $$;
revoke all on function public._sincronizar_saldo(uuid, text) from public;

create or replace function public.pontos_saldo(p_store uuid, p_phone text)
returns numeric language plpgsql security definer set search_path = public as $$
declare v_c text := public.fone_canonico(p_phone); v_n text;
begin
  v_n := left(v_c, 2) || '9' || substr(v_c, 3);
  return coalesce((select sum(points) from public.loyalty_points_ledger where store_id = p_store and phone in (v_c, v_n)), 0);
end $$;

-- os pontos ganhos saem do TOTAL gravado no pedido, nunca de um numero enviado pelo navegador
create or replace function public.creditar_pontos_pedido(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare o public.orders; v_modelo text; v_pontos int; v_c text;
begin
  select * into o from public.orders where id = p_order;
  if not found or o.phone is null or o.origin not in ('WEB', 'APP') or o.status = 'Cancelado' then return; end if;
  select loyalty_model into v_modelo from public.settings where store_id = o.store_id limit 1;
  if coalesce(v_modelo, 'selo') <> 'pontos' then return; end if;
  if o.total < 11 then return; end if;
  v_pontos := floor(o.total / 15) + case when (o.total - floor(o.total / 15) * 15) >= 11 then 1 else 0 end;
  if v_pontos <= 0 then return; end if;
  v_c := public.fone_canonico(o.phone);
  begin
    insert into public.loyalty_points_ledger (store_id, phone, tipo, points, order_id)
    values (o.store_id, v_c, 'ganho', v_pontos, o.id);
  exception when unique_violation then return;
  end;
  perform public._sincronizar_saldo(o.store_id, v_c);
end $$;

create or replace function public.resgatar_pontos_cliente(p_store uuid, p_phone text, p_reward uuid, p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_custo int; v_c text := public.fone_canonico(p_phone); v_n text; v_saldo numeric;
begin
  v_n := left(v_c, 2) || '9' || substr(v_c, 3);
  select points_cost into v_custo from public.loyalty_reward_items
   where id = p_reward and store_id = p_store and coalesce(is_active, true);
  if v_custo is null then raise exception 'Produto de resgate invalido'; end if;
  if p_order is not null and not exists (select 1 from public.orders where id = p_order and store_id = p_store) then
    raise exception 'Pedido invalido';
  end if;
  perform pg_advisory_xact_lock(hashtext(p_store::text || v_c));
  select coalesce(sum(points), 0) into v_saldo from public.loyalty_points_ledger where store_id = p_store and phone in (v_c, v_n);
  if v_saldo < v_custo then
    raise exception 'Saldo insuficiente: tem % pontos, precisa de %.', greatest(0, v_saldo), v_custo;
  end if;
  insert into public.loyalty_points_ledger (store_id, phone, tipo, points, reward_item_id, order_id)
  values (p_store, v_c, 'resgate', -v_custo, p_reward, p_order);
  perform public._sincronizar_saldo(p_store, v_c);
end $$;

-- permissoes: o site (anon) e o painel (authenticated) chamam; ninguem mais
revoke all on function public.cliente_por_telefone(uuid, text[]) from public;
revoke all on function public.salvar_cliente(jsonb) from public;
revoke all on function public.ultimo_pedido_por_telefone(uuid, text) from public;
revoke all on function public.avaliar_pedido(uuid, int, text) from public;
revoke all on function public.selos_do_cliente(uuid, text) from public;
revoke all on function public.resgatar_selos(uuid, text) from public;
revoke all on function public.pontos_saldo(uuid, text) from public;
revoke all on function public.creditar_pontos_pedido(uuid) from public;
revoke all on function public.resgatar_pontos_cliente(uuid, text, uuid, uuid) from public;
grant execute on function public.fone_canonico(text, text) to anon, authenticated;
grant execute on function public.cliente_por_telefone(uuid, text[]) to anon, authenticated;
grant execute on function public.salvar_cliente(jsonb) to anon, authenticated;
grant execute on function public.ultimo_pedido_por_telefone(uuid, text) to anon, authenticated;
grant execute on function public.avaliar_pedido(uuid, int, text) to anon, authenticated;
grant execute on function public.selos_do_cliente(uuid, text) to anon, authenticated;
grant execute on function public.resgatar_selos(uuid, text) to anon, authenticated;
grant execute on function public.pontos_saldo(uuid, text) to anon, authenticated;
grant execute on function public.creditar_pontos_pedido(uuid) to anon, authenticated;
grant execute on function public.resgatar_pontos_cliente(uuid, text, uuid, uuid) to anon, authenticated;
