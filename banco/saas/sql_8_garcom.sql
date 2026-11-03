-- SQL 8: acesso do garcom por PIN da loja, validado no servidor (so para lojas PDV; comissao nao tem garcom).

alter table public.loja_equipe add column if not exists garcom_pin text;
alter table public.loja_equipe add column if not exists garcom_token text;
alter table public.loja_equipe add column if not exists garcom_falhas int default 0;
alter table public.loja_equipe add column if not exists garcom_bloqueado_ate timestamptz;

-- trocar o PIN gera um token novo e derruba o acesso de quem estava logado
create or replace function public.loja_equipe_gira_token()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  if (tg_op = 'INSERT' and new.garcom_pin is not null) or (tg_op = 'UPDATE' and new.garcom_pin is distinct from old.garcom_pin) then
    new.garcom_token := case when new.garcom_pin is null or new.garcom_pin = '' then null else encode(gen_random_bytes(24), 'hex') end;
    new.garcom_falhas := 0;
    new.garcom_bloqueado_ate := null;
  end if;
  return new;
end $$;
drop trigger if exists loja_equipe_gira_token on public.loja_equipe;
create trigger loja_equipe_gira_token before insert or update on public.loja_equipe
  for each row execute function public.loja_equipe_gira_token();

-- lojas PDV que ja existem continuam entrando com o PIN que o app usava (o dono pode trocar nas configuracoes)
insert into public.loja_equipe (store_id, garcom_pin)
select id, 'PIN_ANTIGO_REMOVIDO' from public.stores where coalesce(modelo, 'pdv') <> 'comissao'
on conflict (store_id) do update set garcom_pin = coalesce(public.loja_equipe.garcom_pin, excluded.garcom_pin);

create or replace function public.garcom_login(p_store uuid, p_pin text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare e public.loja_equipe;
begin
  select * into e from public.loja_equipe where store_id = p_store;
  if not found or e.garcom_pin is null or e.garcom_pin = '' then
    return jsonb_build_object('ok', false, 'erro', 'O acesso do garcom nao esta ativado nesta loja.');
  end if;
  if e.garcom_bloqueado_ate is not null and e.garcom_bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'erro', 'Muitas tentativas. Tente de novo em alguns minutos.');
  end if;
  if p_pin is distinct from e.garcom_pin then
    update public.loja_equipe set garcom_falhas = coalesce(garcom_falhas, 0) + 1,
           garcom_bloqueado_ate = case when coalesce(garcom_falhas, 0) + 1 >= 8 then now() + interval '15 minutes' else garcom_bloqueado_ate end
     where store_id = p_store;
    return jsonb_build_object('ok', false, 'erro', 'PIN Incorreto');
  end if;
  update public.loja_equipe set garcom_falhas = 0 where store_id = p_store;
  return jsonb_build_object('ok', true, 'token', e.garcom_token);
end $$;

create or replace function public._garcom_valido(p_store uuid, p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or not exists (select 1 from public.loja_equipe where store_id = p_store and garcom_token is not null and garcom_token = p_token) then
    raise exception 'Sessao expirada. Entre de novo.';
  end if;
end $$;
revoke all on function public._garcom_valido(uuid, text) from public;

create or replace function public.garcom_pedidos_ativos(p_store uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public._garcom_valido(p_store, p_token);
  return coalesce((select jsonb_agg(to_jsonb(o) order by o.timestamp desc) from public.orders o
    where o.store_id = p_store and o.status in ('Novo', 'Em Produção', 'A Caminho', 'Conta Solicitada', 'No Portão')), '[]'::jsonb);
end $$;

create or replace function public.garcom_pedidos_mesa(p_store uuid, p_token text, p_mesa int)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform public._garcom_valido(p_store, p_token);
  return coalesce((select jsonb_agg(to_jsonb(o) order by o.timestamp asc) from public.orders o
    where o.store_id = p_store and o.table_number::text = p_mesa::text and o.status not in ('Entregue', 'Cancelado')), '[]'::jsonb);
end $$;

-- grava um pedido novo (sem id) ou atualiza um existente (com p_id), sempre dentro da propria loja
create or replace function public.garcom_gravar_pedido(p_store uuid, p_token text, p_id uuid, p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_permitidas text[] := array['timestamp','daily_order_number','customer_name','phone','address','reference_point','order_type','payment_method','status','change_for','items','total','printed','observation','table_number','comanda_number','discount','tax','delivery_fee','combo_price','origin','status_history','courier_id','courier_name','is_loyalty_eligible','rating','feedback'];
  v_cols text; v_row jsonb; k text;
begin
  perform public._garcom_valido(p_store, p_token);
  if p_id is null then
    select string_agg(quote_ident(x), ',') into v_cols from (select jsonb_object_keys(p) x) t where x = any(v_permitidas);
    p := p || jsonb_build_object('store_id', p_store);
    execute format('insert into public.orders (store_id, %s) select store_id, %s from jsonb_populate_record(null::public.orders, $1) returning to_jsonb(orders)', v_cols, v_cols)
      using p into v_row;
    return v_row;
  end if;
  if not exists (select 1 from public.orders where id = p_id and store_id = p_store) then raise exception 'Pedido nao encontrado'; end if;
  for k in select jsonb_object_keys(p) loop
    if k = any(v_permitidas) then
      execute format('update public.orders set %I = (jsonb_populate_record(null::public.orders, $1)).%I where id = $2 and store_id = $3', k, k) using p, p_id, p_store;
    end if;
  end loop;
  select to_jsonb(o) into v_row from public.orders o where o.id = p_id;
  return v_row;
end $$;

create or replace function public.garcom_fechar_mesa(p_store uuid, p_token text, p_mesa int, p_pagamento text, p_troco text)
returns int language plpgsql security definer set search_path = public as $$
declare v_n int; v_troco numeric;
begin
  perform public._garcom_valido(p_store, p_token);
  if p_pagamento not in ('Dinheiro', 'Cartão', 'PIX') then raise exception 'Forma de pagamento invalida'; end if;
  begin v_troco := nullif(replace(regexp_replace(coalesce(p_troco, ''), '[^0-9,.]', '', 'g'), ',', '.'), '')::numeric; exception when others then v_troco := null; end;
  update public.orders set status = 'Entregue', payment_method = p_pagamento, change_for = v_troco
   where store_id = p_store and table_number::text = p_mesa::text and status not in ('Entregue', 'Cancelado');
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke all on function public.garcom_login(uuid, text) from public;
revoke all on function public.garcom_pedidos_ativos(uuid, text) from public;
revoke all on function public.garcom_pedidos_mesa(uuid, text, int) from public;
revoke all on function public.garcom_gravar_pedido(uuid, text, uuid, jsonb) from public;
revoke all on function public.garcom_fechar_mesa(uuid, text, int, text, text) from public;
grant execute on function public.garcom_login(uuid, text) to anon, authenticated;
grant execute on function public.garcom_pedidos_ativos(uuid, text) to anon, authenticated;
grant execute on function public.garcom_pedidos_mesa(uuid, text, int) to anon, authenticated;
grant execute on function public.garcom_gravar_pedido(uuid, text, uuid, jsonb) to anon, authenticated;
grant execute on function public.garcom_fechar_mesa(uuid, text, int, text, text) to anon, authenticated;
