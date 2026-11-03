-- SQL 12: brechas da rodada 2 de ataque (02/11/2026)

-- 1. funcoes internas nao devem ser chamaveis pela chave publica
revoke execute on function public._garcom_valido(uuid, text) from anon, authenticated;
revoke execute on function public._entregador_valido(uuid, text) from anon, authenticated;
revoke execute on function public._sincronizar_saldo(uuid, text) from anon, authenticated;

-- 2. freio de volume atomico: o gatilho serializa os pedidos do site por loja, entao pedidos simultaneos nao furam o limite
create or replace function public.orders_freio_site()
returns trigger language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if new.origin is null or new.origin not in ('WEB', 'APP') then return new; end if;
  perform pg_advisory_xact_lock(hashtext('freio:' || new.store_id::text));
  if new.phone is not null then
    -- pedido identico (mesmos itens e total) nos ultimos 5 minutos: e clique duplo ou reenvio
    if exists (select 1 from public.orders where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP')
                  and total = new.total and items = new.items and timestamp > now() - interval '5 minutes') then
      raise exception 'Este pedido ja foi enviado.';
    end if;
    -- um pedido por minuto e no maximo 3 em 10 minutos para o mesmo telefone
    if exists (select 1 from public.orders where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP')
                  and timestamp > now() - interval '1 minute') then
      raise exception 'Aguarde 1 minuto para fazer outro pedido.';
    end if;
    select count(*) into v from public.orders
     where store_id = new.store_id and phone = new.phone and origin in ('WEB', 'APP') and timestamp > now() - interval '10 minutes';
    if v >= 3 then raise exception 'Muitos pedidos em pouco tempo. Aguarde alguns minutos.'; end if;
  end if;
  select count(*) into v from public.orders
   where store_id = new.store_id and origin in ('WEB', 'APP') and timestamp > now() - interval '10 minutes';
  if v >= 60 then raise exception 'A loja esta com muitos pedidos agora. Tente em instantes.'; end if;
  return new;
end $$;
drop trigger if exists orders_freio_site on public.orders;
create trigger orders_freio_site before insert on public.orders
  for each row execute function public.orders_freio_site();

-- 3. cadastro de entregador: tentativas do codigo da loja limitadas (10 erros = 15 min de bloqueio)
alter table public.loja_equipe add column if not exists cadastro_falhas int default 0;
alter table public.loja_equipe add column if not exists cadastro_bloqueado_ate timestamptz;

create or replace function public.entregador_cadastrar(p_store uuid, p_name text, p_phone text, p_senha text, p_codigo text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare e public.loja_equipe; v_fone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if not exists (select 1 from public.stores where id = p_store and coalesce(is_active, false)) then
    return jsonb_build_object('ok', false, 'erro', 'Loja indisponivel');
  end if;
  select * into e from public.loja_equipe where store_id = p_store;
  if not found or e.courier_access_code is null or e.courier_access_code = '' then
    return jsonb_build_object('ok', false, 'erro', 'O cadastro de entregador esta desativado nesta loja. Peca ao gerente para cadastrar voce.');
  end if;
  if e.cadastro_bloqueado_ate is not null and e.cadastro_bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'erro', 'Muitas tentativas. Tente de novo em alguns minutos.');
  end if;
  if p_codigo is distinct from e.courier_access_code then
    update public.loja_equipe set cadastro_falhas = coalesce(cadastro_falhas, 0) + 1,
           cadastro_bloqueado_ate = case when coalesce(cadastro_falhas, 0) + 1 >= 3 then now() + interval '15 minutes' else cadastro_bloqueado_ate end
     where store_id = p_store;
    return jsonb_build_object('ok', false, 'erro', 'Codigo da loja incorreto. Peca ao gerente.');
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'erro', 'Informe o nome'); end if;
  if length(v_fone) < 10 then return jsonb_build_object('ok', false, 'erro', 'Telefone invalido'); end if;
  if length(coalesce(p_senha, '')) < 4 then return jsonb_build_object('ok', false, 'erro', 'A senha deve ter pelo menos 4 caracteres.'); end if;
  if exists (select 1 from public.couriers where store_id = p_store and phone = v_fone) then
    return jsonb_build_object('ok', false, 'erro', 'Telefone ja cadastrado para este estabelecimento.');
  end if;
  update public.loja_equipe set cadastro_falhas = 0 where store_id = p_store;
  insert into public.couriers (store_id, name, phone, password, is_active) values (p_store, left(trim(p_name), 100), v_fone, p_senha, true);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.entregador_cadastrar(uuid, text, text, text, text) from public;
grant execute on function public.entregador_cadastrar(uuid, text, text, text, text) to anon, authenticated;

-- limpeza dos pedidos e clientes de teste
delete from public.orders where customer_name in ('TESTE QUEBRA', 'TESTE FREIO', '<img src=x onerror=alert(1)>');
delete from public.customers where name like 'TESTE QUEBRA%';
select (select count(*) from public.orders where customer_name like 'TESTE%') as pedidos_teste_restantes,
       (select count(*) from public.customers where name like 'TESTE QUEBRA%') as clientes_teste_restantes;
