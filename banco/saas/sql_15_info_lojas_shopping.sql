-- SQL 15: aberto agora e tempo medio das lojas na vitrine (Pede Aki).
-- Uma funcao de LEITURA publica que devolve, so das lojas que aparecem no shopping:
--   horario de funcionamento (para a vitrine calcular "aberta agora" com a mesma regra da pagina da loja)
--   e o tempo tipico de entrega, calculado dos pedidos ENTREGUES dos ultimos 30 dias (mediana).
-- Nao devolve nenhum dado de cliente nem nenhuma chave. Nao muda politica de tabela nenhuma.
-- O tempo so aparece quando ha pelo menos 5 entregas na amostra; senao vem nulo e a vitrine nao mostra nada.

create or replace function public.lojas_shopping_info()
returns table (
  store_id uuid,
  manual_status text,
  days_of_week jsonb,
  opening_time text,
  closing_time text,
  custom_hours jsonb,
  tempo_tipico_min integer,
  amostra integer
)
language sql stable security definer set search_path = public as $$
  with lojas as (
    select s.id from public.stores s where s.aparecer_no_shopping = true and s.is_active = true
  ),
  entregas as (
    select o.store_id,
           extract(epoch from (
             (select max((h->>'timestamp')::timestamptz)
                from jsonb_array_elements(coalesce(o.status_history, '[]'::jsonb)) h
               where h->>'status' = 'Entregue') - o."timestamp"::timestamptz
           )) / 60.0 as minutos
      from public.orders o
     where o.store_id in (select id from lojas)
       and o.status = 'Entregue'
       and o.origin in ('WEB', 'APP')
       and o."timestamp" > now() - interval '30 days'
  ),
  tempos as (
    select e.store_id,
           count(*)::integer as amostra,
           round(percentile_cont(0.5) within group (order by e.minutos))::integer as mediana
      from entregas e
     where e.minutos between 3 and 180
     group by e.store_id
  )
  select l.id,
         st.manual_status::text,
         to_jsonb(st.days_of_week),
         st.opening_time::text,
         st.closing_time::text,
         to_jsonb(st.custom_hours_per_day),
         case when coalesce(t.amostra, 0) >= 5 then t.mediana end,
         coalesce(t.amostra, 0)
    from lojas l
    left join public.settings st on st.store_id = l.id
    left join tempos t on t.store_id = l.id;
$$;

revoke all on function public.lojas_shopping_info() from public;
grant execute on function public.lojas_shopping_info() to anon, authenticated;
