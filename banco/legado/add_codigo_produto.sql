-- Código do produto para lançamento rápido por teclado no balcão.
--
-- REGRA: código SEMPRE >= 100.
-- Motivo: no atalho do balcão os números 1..30 são o NÚMERO DA MESA. Começar os
-- produtos em 100 garante que nunca haja ambiguidade entre "mesa 25" e "produto 25".
--
-- O código é único por loja (duas lojas podem repetir o mesmo número).

ALTER TABLE menu_items
ADD COLUMN IF NOT EXISTS codigo INTEGER;

-- Impede código abaixo de 100 (a regra vale na origem, não só na tela).
ALTER TABLE menu_items
DROP CONSTRAINT IF EXISTS menu_items_codigo_min;

ALTER TABLE menu_items
ADD CONSTRAINT menu_items_codigo_min
CHECK (codigo IS NULL OR codigo >= 100);

-- Não deixa dois produtos da mesma loja com o mesmo código.
DROP INDEX IF EXISTS menu_items_codigo_unico_por_loja;

CREATE UNIQUE INDEX menu_items_codigo_unico_por_loja
ON menu_items (store_id, codigo)
WHERE codigo IS NOT NULL;

-- Consulta útil: ver os códigos já usados
-- SELECT codigo, name FROM menu_items WHERE codigo IS NOT NULL ORDER BY codigo;
