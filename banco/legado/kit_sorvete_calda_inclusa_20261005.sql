-- Kit "sorvete 1,8lts + cascao + calda" (produto 277): R$48 E PONTO FINAL (pedido da dona).
-- Remove do produto 277 TODO adicional pago (price > 0). Ficam os itens gratis (sabores/opcoes)
-- e entram 3 caldas gratis para o cliente escolher. Total sempre R$48.
-- So mexe no produto 277.

-- PREVIA (so le): quantos itens e quantos sao pagos
select (select jsonb_array_length(allowed_addons) from menu_items where id = 277) total_antes,
       (select count(*) from addons a, menu_items m
         where m.id = 277 and m.allowed_addons ? a.id::text and a.price > 0) pagos_a_remover;

-- APLICAR
update menu_items m
set allowed_addons = (
      select coalesce(jsonb_agg(distinct v), '[]'::jsonb)
      from jsonb_array_elements(m.allowed_addons || '["7b5dbbe2-77b1-4840-a650-34921ae1ff4e","0dcbea87-8f75-4593-8cf3-98215387be22","ac17a3e0-9797-4533-b372-59da51fcf9fc"]'::jsonb) v
      where not exists (select 1 from addons a where a.id::text = v #>> '{}' and a.price > 0)
    )
where m.id = 277;

-- CONFERIR: nenhum pago sobrando (deve dar 0) e o total novo
select jsonb_array_length(allowed_addons) total_depois,
       (select count(*) from addons a where m.allowed_addons ? a.id::text and a.price > 0) pagos_sobrando
from menu_items m where id = 277;
