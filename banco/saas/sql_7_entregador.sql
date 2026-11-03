-- SQL 7: entregador seguro (Rodada 1, parte 3). Nao fecha tabelas ainda; so acrescenta e protege as senhas.

create extension if not exists pgcrypto with schema extensions;

alter table public.couriers add column if not exists session_token text;
alter table public.couriers add column if not exists falhas int default 0;
alter table public.couriers add column if not exists bloqueado_ate timestamptz;

-- senhas passam a ser guardadas em hash (bcrypt); quem cadastra/edita continua mandando a senha normal
create or replace function public.couriers_hash_senha()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  if tg_op = 'UPDATE' and (new.password is null or new.password = '') then
    new.password := old.password;   -- editar sem mexer na senha mantem a senha
  end if;
  if new.password is not null and new.password <> '' and new.password !~ '^\$2[aby]\$'
     and (tg_op = 'INSERT' or new.password is distinct from old.password) then
    new.password := crypt(new.password, gen_salt('bf'));
    new.session_token := null;      -- trocar a senha derruba as sessoes abertas
  end if;
  return new;
end $$;
drop trigger if exists couriers_hash_senha on public.couriers;
create trigger couriers_hash_senha before insert or update on public.couriers
  for each row execute function public.couriers_hash_senha();

-- converte as senhas que ja existem em texto puro
update public.couriers set password = extensions.crypt(password, extensions.gen_salt('bf'))
 where password is not null and password <> '' and password !~ '^\$2[aby]\$';

-- codigo de cadastro de entregador sai da tabela publica (settings) para uma tabela so do dono
create table if not exists public.loja_equipe (
  store_id uuid primary key references public.stores(id) on delete cascade,
  courier_access_code text
);
alter table public.loja_equipe enable row level security;
drop policy if exists dono_total on public.loja_equipe;
create policy dono_total on public.loja_equipe for all to authenticated
  using (public.owns_store(store_id)) with check (public.owns_store(store_id));

insert into public.loja_equipe (store_id, courier_access_code)
select store_id, courier_access_code from public.settings
 where courier_access_code is not null and courier_access_code <> ''
on conflict (store_id) do nothing;
update public.settings set courier_access_code = null where courier_access_code is not null;

-- toda loja passa a ter sua linha de configuracoes desde o nascimento (loja nova sem ela nao conseguia salvar nada)
create or replace function public.stores_cria_settings()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.settings (store_id) select new.id where not exists (select 1 from public.settings where store_id = new.id);
  return new;
end $$;
drop trigger if exists stores_cria_settings on public.stores;
create trigger stores_cria_settings after insert on public.stores for each row execute function public.stores_cria_settings();

do $$
begin
  insert into public.settings (store_id) select s.id from public.stores s where not exists (select 1 from public.settings x where x.store_id = s.id);
exception when others then
  raise notice 'Nao foi possivel criar a linha de configuracoes das lojas existentes: %', sqlerrm;
end $$;

-- ---------------- funcoes do entregador (autenticam por id + token da sessao) ----------------
create or replace function public.entregador_login(p_store uuid, p_phone text, p_senha text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare c public.couriers; v_tok text;
begin
  select * into c from public.couriers
   where store_id = p_store and phone = regexp_replace(coalesce(p_phone, ''), '\D', '', 'g') and coalesce(is_active, true);
  if not found then return jsonb_build_object('ok', false, 'erro', 'Telefone ou senha invalidos'); end if;
  if c.bloqueado_ate is not null and c.bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'erro', 'Muitas tentativas. Tente de novo em alguns minutos.');
  end if;
  if c.password is null or c.password = '' or crypt(coalesce(p_senha, ''), c.password) <> c.password then
    update public.couriers set falhas = coalesce(falhas, 0) + 1,
           bloqueado_ate = case when coalesce(falhas, 0) + 1 >= 5 then now() + interval '15 minutes' else bloqueado_ate end
     where id = c.id;
    return jsonb_build_object('ok', false, 'erro', 'Telefone ou senha invalidos');
  end if;
  v_tok := encode(gen_random_bytes(24), 'hex');
  update public.couriers set session_token = v_tok, falhas = 0, bloqueado_ate = null where id = c.id;
  return jsonb_build_object('ok', true, 'token', v_tok,
    'courier', jsonb_build_object('id', c.id, 'store_id', c.store_id, 'name', c.name, 'phone', c.phone, 'is_active', c.is_active, 'created_at', c.created_at));
end $$;

create or replace function public.entregador_cadastrar(p_store uuid, p_name text, p_phone text, p_senha text, p_codigo text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v_code text; v_fone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if not exists (select 1 from public.stores where id = p_store and coalesce(is_active, false)) then
    return jsonb_build_object('ok', false, 'erro', 'Loja indisponivel');
  end if;
  select courier_access_code into v_code from public.loja_equipe where store_id = p_store;
  if v_code is null or v_code = '' then
    return jsonb_build_object('ok', false, 'erro', 'O cadastro de entregador esta desativado nesta loja. Peca ao gerente para cadastrar voce.');
  end if;
  if p_codigo is distinct from v_code then return jsonb_build_object('ok', false, 'erro', 'Codigo da loja incorreto. Peca ao gerente.'); end if;
  if length(trim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'erro', 'Informe o nome'); end if;
  if length(v_fone) < 10 then return jsonb_build_object('ok', false, 'erro', 'Telefone invalido'); end if;
  if length(coalesce(p_senha, '')) < 4 then return jsonb_build_object('ok', false, 'erro', 'A senha deve ter pelo menos 4 caracteres.'); end if;
  if exists (select 1 from public.couriers where store_id = p_store and phone = v_fone) then
    return jsonb_build_object('ok', false, 'erro', 'Telefone ja cadastrado para este estabelecimento.');
  end if;
  insert into public.couriers (store_id, name, phone, password, is_active) values (p_store, left(trim(p_name), 100), v_fone, p_senha, true);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public._entregador_valido(p_courier uuid, p_token text)
returns public.couriers language plpgsql security definer set search_path = public as $$
declare c public.couriers;
begin
  select * into c from public.couriers
   where id = p_courier and coalesce(is_active, true) and session_token is not null and session_token = p_token;
  if not found then raise exception 'Sessao expirada. Entre de novo.'; end if;
  return c;
end $$;
revoke all on function public._entregador_valido(uuid, text) from public;

create or replace function public.entregador_pedidos_prontos(p_courier uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token);
begin
  return coalesce((select jsonb_agg(to_jsonb(o) order by o.timestamp asc) from public.orders o
    where o.store_id = c.store_id and o.order_type = 'Entrega' and o.status in ('Em Produção', 'Novo') and o.courier_id is null), '[]'::jsonb);
end $$;

create or replace function public.entregador_entregas_ativas(p_courier uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token);
begin
  return coalesce((select jsonb_agg(to_jsonb(o) order by o.timestamp desc) from public.orders o
    where o.courier_id = c.id and o.status in ('A Caminho', 'No Portão')), '[]'::jsonb);
end $$;

create or replace function public.entregador_historico(p_courier uuid, p_token text, p_ini timestamptz, p_fim timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token);
begin
  return coalesce((select jsonb_agg(to_jsonb(o) order by o.timestamp desc) from public.orders o
    where o.courier_id = c.id and o.status = 'Entregue' and o.timestamp >= p_ini and o.timestamp <= p_fim), '[]'::jsonb);
end $$;

create or replace function public.entregador_total(p_courier uuid, p_token text)
returns int language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token);
begin
  return (select count(*)::int from public.orders where courier_id = c.id and status = 'Entregue');
end $$;

create or replace function public.entregador_pegar(p_courier uuid, p_token text, p_order uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token); v jsonb;
begin
  update public.orders set courier_id = c.id, courier_name = c.name, status = 'A Caminho',
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', 'A Caminho', 'timestamp', now()))
   where id = p_order and store_id = c.store_id and order_type = 'Entrega' and courier_id is null and status in ('Novo', 'Em Produção')
   returning to_jsonb(orders) into v;
  if v is null then raise exception 'Este pedido ja foi pego por outro entregador ou nao esta disponivel.'; end if;
  return v;
end $$;

create or replace function public.entregador_status(p_courier uuid, p_token text, p_order uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.couriers := public._entregador_valido(p_courier, p_token); v jsonb;
begin
  if p_status not in ('A Caminho', 'No Portão', 'Entregue') then raise exception 'Status invalido'; end if;
  update public.orders set status = p_status,
         status_history = coalesce(status_history, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('status', p_status, 'timestamp', now()))
   where id = p_order and courier_id = c.id and status in ('A Caminho', 'No Portão')
   returning to_jsonb(orders) into v;
  if v is null then raise exception 'Pedido nao encontrado entre as suas entregas.'; end if;
  return v;
end $$;

revoke all on function public.entregador_login(uuid, text, text) from public;
revoke all on function public.entregador_cadastrar(uuid, text, text, text, text) from public;
revoke all on function public.entregador_pedidos_prontos(uuid, text) from public;
revoke all on function public.entregador_entregas_ativas(uuid, text) from public;
revoke all on function public.entregador_historico(uuid, text, timestamptz, timestamptz) from public;
revoke all on function public.entregador_total(uuid, text) from public;
revoke all on function public.entregador_pegar(uuid, text, uuid) from public;
revoke all on function public.entregador_status(uuid, text, uuid, text) from public;
grant execute on function public.entregador_login(uuid, text, text) to anon, authenticated;
grant execute on function public.entregador_cadastrar(uuid, text, text, text, text) to anon, authenticated;
grant execute on function public.entregador_pedidos_prontos(uuid, text) to anon, authenticated;
grant execute on function public.entregador_entregas_ativas(uuid, text) to anon, authenticated;
grant execute on function public.entregador_historico(uuid, text, timestamptz, timestamptz) to anon, authenticated;
grant execute on function public.entregador_total(uuid, text) to anon, authenticated;
grant execute on function public.entregador_pegar(uuid, text, uuid) to anon, authenticated;
grant execute on function public.entregador_status(uuid, text, uuid, text) to anon, authenticated;
