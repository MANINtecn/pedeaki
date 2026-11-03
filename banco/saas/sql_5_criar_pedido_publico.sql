-- SQL 5: criacao de pedido validada pelo servidor (Rodada 1, parte 1).
-- Nao remove nada e nao quebra o que existe: so ACRESCENTA a funcao.
-- O site do cliente passa a chamar esta funcao em vez de gravar direto na tabela orders.

create or replace function public.criar_pedido_publico(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store   uuid := nullif(p->>'store_id', '')::uuid;
  v_loja    record;
  v_cfg     record;
  v_item    jsonb;
  v_add     jsonb;
  v_id_txt  text;
  v_db      numeric;
  v_preco   numeric;
  v_qtd     numeric;
  v_adds    numeric;
  v_soma    numeric := 0;
  v_fid     numeric := 0;
  v_gratis  int := 0;
  v_total   numeric := coalesce((p->>'total')::numeric, -1);
  v_frete   numeric := coalesce((p->>'delivery_fee')::numeric, 0);
  v_pagto   text := p->>'payment_method';
  v_tipo    text := p->>'order_type';
  v_origem  text := p->>'origin';
  v_pct     numeric := 0;
  v_combo   numeric := 0;
  v_cfg_frete numeric := 0;
  v_troco   numeric;
  v_min     numeric := 15;
  v_dispo   boolean;
  v_recentes int;
  v_estrito boolean;
  v_add_db  numeric;
  v_end     text;
  v_zfee    numeric;
  v_zona    numeric;
  v_frete_min numeric;
  v_minimo  numeric;
  v_linha   public.orders;
begin
  if v_store is null then raise exception 'Pedido sem loja'; end if;

  select id, is_active, aceita_dinheiro, modelo into v_loja from public.stores where id = v_store;
  if not found or coalesce(v_loja.is_active, false) = false then
    raise exception 'Loja indisponivel';
  end if;

  -- so o site e o app do cliente entram por aqui; balcao, mesa e garcom seguem outro caminho
  -- lojas de comissao (novas) seguem a regra completa; as antigas (PDV) ficam mais tolerantes para nao quebrar o que ja funciona
  v_estrito := coalesce(v_loja.modelo, 'pdv') = 'comissao';

  if v_origem is null or v_origem not in ('WEB', 'APP') then
    raise exception 'Origem do pedido nao permitida';
  end if;
  if v_tipo not in ('Entrega', 'Retirada') then
    raise exception 'Tipo de pedido nao permitido';
  end if;
  if v_pagto not in ('Dinheiro', 'Cartão', 'PIX') then
    raise exception 'Forma de pagamento invalida';
  end if;
  if v_pagto = 'Dinheiro' and coalesce(v_loja.aceita_dinheiro, true) = false then
    raise exception 'Esta loja nao aceita pagamento em dinheiro';
  end if;

  if jsonb_typeof(p->'items') <> 'array' or jsonb_array_length(p->'items') = 0 or jsonb_array_length(p->'items') > 60 then
    raise exception 'Pedido sem itens';
  end if;

  select coalesce(combo_price, 0) as combo, coalesce(app_discount_percentage, 0) as pct,
         coalesce(is_app_discount_enabled, false) as ligado, coalesce(delivery_fee, 0) as frete,
         coalesce(min_order_value, 15) as minimo
    into v_cfg from public.settings where store_id = v_store limit 1;
  if found then
    v_combo := v_cfg.combo;
    v_cfg_frete := v_cfg.frete;
    v_min := v_cfg.minimo;
    if v_cfg.ligado then v_pct := v_cfg.pct; end if;
  end if;

  for v_item in select * from jsonb_array_elements(p->'items') loop
    v_id_txt := v_item->>'id';
    v_preco  := coalesce((v_item->>'price')::numeric, 0);
    v_qtd    := coalesce((v_item->>'quantity')::numeric, 1);
    if v_qtd <= 0 or v_qtd > 99 then raise exception 'Quantidade invalida'; end if;

    -- linha de desconto de fidelidade (o app limita a R$ 20)
    if v_id_txt = '888888' then
      if v_estrito then raise exception 'Desconto de fidelidade nao disponivel nesta loja'; end if;
      if v_preco > 0 then raise exception 'Desconto invalido'; end if;
      v_fid := v_fid + (-v_preco) * v_qtd;
      if v_fid > 20.01 then raise exception 'Desconto acima do permitido'; end if;
      v_soma := v_soma + v_preco * v_qtd;
      continue;
    end if;

    -- preco de referencia: produto da loja ou promocao ativa da loja
    v_db := null;
    v_dispo := true;
    select price, coalesce(is_available, true) into v_db, v_dispo from public.menu_items where id::text = v_id_txt and store_id = v_store limit 1;
    if v_db is not null and not v_dispo then raise exception 'O item % esta indisponivel no momento', coalesce(v_item->>'name', v_id_txt); end if;
    if v_db is null then
      select price into v_db from public.promotions where id::text = v_id_txt and store_id = v_store and coalesce(is_active, true) limit 1;
    end if;
    if v_db is null then raise exception 'Item % nao existe no cardapio desta loja', coalesce(v_item->>'name', v_id_txt); end if;

    -- item de resgate de fidelidade entra a zero, no maximo um por pedido
    if v_preco = 0 and (coalesce(v_item->>'isLoyaltyRedemption', 'false') = 'true' or coalesce(v_item->>'notes', '') ilike '%fidelidade%') then
      if v_estrito then raise exception 'Item gratis nao disponivel nesta loja'; end if;
      v_gratis := v_gratis + 1;
      if v_gratis > 1 then raise exception 'Mais de um item gratis no pedido'; end if;
    elsif coalesce((v_item->>'weightKg')::numeric, 0) > 0 then
      if v_estrito then raise exception 'Item por peso nao e vendido pelo site'; end if;
      if v_preco < 0 then raise exception 'Preco invalido'; end if;
    elsif v_preco < v_db - 0.01 then
      raise exception 'Preco do item % diferente do cardapio', coalesce(v_item->>'name', v_id_txt);
    end if;

    -- complementos: nunca negativos
    v_adds := 0;
    if jsonb_typeof(v_item->'selectedAddons') = 'array' then
      for v_add in select * from jsonb_array_elements(v_item->'selectedAddons') loop
        if coalesce((v_add->>'price')::numeric, 0) < 0 then raise exception 'Complemento com preco invalido'; end if;
        -- complemento tem que existir na loja e nao pode custar menos que o cadastrado
        v_add_db := null;
        select price into v_add_db from public.addons where id::text = (v_add->>'id') and store_id = v_store limit 1;
        if v_add_db is null then
          if v_estrito then raise exception 'Complemento % nao existe nesta loja', coalesce(v_add->>'name', v_add->>'id'); end if;
        elsif coalesce((v_add->>'price')::numeric, 0) < v_add_db - 0.01 then
          raise exception 'Preco do complemento % diferente do cadastrado', coalesce(v_add->>'name', v_add->>'id');
        end if;
        v_adds := v_adds + coalesce((v_add->>'price')::numeric, 0);
      end loop;
    end if;

    v_soma := v_soma + (v_preco + v_adds + case when coalesce(v_item->>'isCombo', 'false') = 'true' then v_combo else 0 end) * v_qtd;
  end loop;

  -- frete: nao pode ser menor que a menor taxa da loja
  if v_tipo = 'Entrega' then
    -- taxa do bairro que aparece no endereco ("... - Bairro: PINDAIBA"); o nome mais longo vence
    v_end := upper(translate(coalesce(p->>'address', ''), 'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç', 'AAAAEEIOOOUCaaaaeeiooouc'));
    select fee into v_zfee from public.delivery_zones
     where store_id = v_store and coalesce(is_active, true)
       and position(upper(translate(neighborhood_name, 'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç', 'AAAAEEIOOOUCaaaaeeiooouc')) in v_end) > 0
     order by length(neighborhood_name) desc limit 1;
    select min(fee) into v_zona from public.delivery_zones where store_id = v_store and coalesce(is_active, true);
    v_frete_min := coalesce(v_zfee, v_zona, v_cfg_frete);
    if v_frete < v_frete_min - 0.01 then raise exception 'Taxa de entrega menor que a da loja (minimo %)', round(v_frete_min, 2); end if;
  else
    v_frete := 0;
  end if;

  -- total: soma dos itens, menos o desconto de retirada, mais o frete (com 10 centavos de folga)
  v_minimo := v_soma - case when v_tipo = 'Retirada' then v_soma * v_pct / 100 else 0 end + v_frete;
  if v_total < 0 or v_total + 0.10 < v_minimo then
    raise exception 'Total do pedido diferente do calculado (esperado %)', round(v_minimo, 2);
  end if;
  if v_total > v_minimo + 500 then raise exception 'Total do pedido invalido'; end if;
  if v_tipo = 'Entrega' and v_minimo < v_min - 0.01 then raise exception 'Pedido minimo para entrega: R$ %', round(v_min, 2); end if;

  -- freio de volume: poucos pedidos por telefone e por loja em 10 minutos
  if nullif(p->>'phone', '') is not null then
    select count(*) into v_recentes from public.orders where store_id = v_store and phone = p->>'phone' and origin in ('WEB', 'APP') and timestamp > now() - interval '10 minutes';
    if v_recentes >= 4 then raise exception 'Muitos pedidos em pouco tempo. Aguarde alguns minutos.'; end if;
  end if;
  select count(*) into v_recentes from public.orders where store_id = v_store and origin in ('WEB', 'APP') and timestamp > now() - interval '10 minutes';
  if v_recentes >= 60 then raise exception 'A loja esta com muitos pedidos agora. Tente em instantes.'; end if;

  -- troco: a coluna e numerica; aceita "50", "R$ 50,00" e ignora o que nao for numero
  begin
    v_troco := nullif(replace(regexp_replace(coalesce(p->>'change_for', ''), '[^0-9,.]', '', 'g'), ',', '.'), '')::numeric;
  exception when others then
    v_troco := null;
  end;

  insert into public.orders (
    customer_name, phone, address, reference_point, order_type, payment_method, status, change_for,
    items, total, store_id, printed, observation, discount, delivery_fee, combo_price, origin,
    is_loyalty_eligible, status_history, timestamp
  ) values (
    left(coalesce(p->>'customer_name', ''), 120),
    nullif(p->>'phone', ''),
    left(coalesce(p->>'address', ''), 300),
    left(coalesce(p->>'reference_point', ''), 200),
    v_tipo, v_pagto, 'Novo', v_troco,
    p->'items', round(v_total, 2), v_store, false, left(coalesce(p->>'observation', ''), 500),
    nullif(p->>'discount', '')::numeric, v_frete, nullif(p->>'combo_price', '')::numeric, v_origem,
    (v_total + coalesce(nullif(p->>'discount', '')::numeric, 0)) >= 35,
    jsonb_build_array(jsonb_build_object('status', 'Novo', 'timestamp', now())),
    now()
  ) returning * into v_linha;

  return to_jsonb(v_linha);
end;
$$;

revoke all on function public.criar_pedido_publico(jsonb) from public;
grant execute on function public.criar_pedido_publico(jsonb) to anon, authenticated;

-- Conferencia: as colunas que a funcao usa precisam existir (deve voltar 12 linhas, todas true)
select c as coluna, exists (
  select 1 from information_schema.columns
  where table_schema = 'public' and (table_name || '.' || column_name) = c
) as existe
from unnest(array[
  'stores.aceita_dinheiro','stores.is_active','settings.combo_price','settings.app_discount_percentage',
  'settings.is_app_discount_enabled','settings.delivery_fee','settings.store_id','delivery_zones.fee',
  'promotions.is_active','orders.change_for','orders.combo_price','orders.status_history'
]) as c;
