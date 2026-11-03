-- AUDITORIA DA FIDELIDADE (05/10/2026)
-- Rodar o BLOCO 1 inteiro. O BLOCO 2 e OPCIONAL (credita pontos retroativos) -- leia antes.
-- Tudo e idempotente: pode rodar de novo sem duplicar nada.

-- ============================== BLOCO 1 (obrigatorio) ==============================
BEGIN;

-- 1a. Novo tipo de lancamento 'estorno_resgate': devolve os pontos de um resgate quando o
--     pedido que entregava o produto e cancelado. Um por pedido.
ALTER TABLE loyalty_points_ledger DROP CONSTRAINT IF EXISTS loyalty_points_ledger_tipo_check;
ALTER TABLE loyalty_points_ledger ADD CONSTRAINT loyalty_points_ledger_tipo_check
    CHECK (tipo IN ('ganho', 'resgate', 'estorno', 'estorno_resgate'));
CREATE UNIQUE INDEX IF NOT EXISTS loyalty_ledger_estorno_resgate_unico
    ON loyalty_points_ledger (order_id)
    WHERE tipo = 'estorno_resgate' AND order_id IS NOT NULL;

-- 1b. Telefone no formato canonico (DDD + 8 digitos, sem o 9) -- o MESMO da tabela customers.
--     Antes os pontos eram gravados com 11 digitos e o cliente (10 digitos) via saldo 0.
UPDATE loyalty_points_ledger
   SET phone = left(phone, 2) || right(phone, 8)
 WHERE phone ~ '^[0-9]{11}$';

-- 1c. Reconstroi o saldo a partir do extrato (o extrato e a fonte da verdade).
INSERT INTO customer_loyalty_points (store_id, phone, points_balance, updated_at)
SELECT store_id, phone, GREATEST(0, SUM(points))::int, now()
  FROM loyalty_points_ledger
 GROUP BY store_id, phone
ON CONFLICT (store_id, phone)
DO UPDATE SET points_balance = EXCLUDED.points_balance, updated_at = now();

DELETE FROM customer_loyalty_points WHERE phone ~ '^[0-9]{11}$';

COMMIT;

-- Conferir (deve mostrar 0 linhas):
SELECT c.phone, c.points_balance, s.soma
  FROM customer_loyalty_points c
  LEFT JOIN (SELECT store_id, phone, SUM(points) AS soma FROM loyalty_points_ledger GROUP BY store_id, phone) s
         ON s.store_id = c.store_id AND s.phone = c.phone
 WHERE c.points_balance <> GREATEST(0, COALESCE(s.soma, 0));


-- ============================== BLOCO 2 (OPCIONAL) ==============================
-- Pontos RETROATIVOS: pedidos do site/app que nunca receberam pontos (maioria de 20 a 27/09,
-- antes de o modelo de pontos estar ativo) e dois cancelamentos que nao foram estornados.
-- Decisao do dono: os clientes passariam a ver pontos que nao sabiam que tinham.
-- Primeiro rode so este SELECT para ver o tamanho (esperado hoje: 51 pedidos, 96 pontos):
SELECT count(*) AS pedidos, COALESCE(sum(pts), 0) AS pontos
  FROM (
    SELECT (floor(o.total / 15) + CASE WHEN o.total - floor(o.total / 15) * 15 >= 11 THEN 1 ELSE 0 END)::int AS pts
      FROM orders o
     WHERE o.origin IN ('WEB', 'APP')
       AND o.status <> 'Cancelado'
       AND o.phone IS NOT NULL
       AND length(regexp_replace(o.phone, '[^0-9]', '', 'g')) >= 10
       AND o.total >= 11
       AND NOT EXISTS (SELECT 1 FROM loyalty_points_ledger l WHERE l.order_id = o.id AND l.tipo = 'ganho')
  ) x;

-- Se quiser aplicar, rode de BEGIN ate COMMIT:
BEGIN;

INSERT INTO loyalty_points_ledger (store_id, phone, tipo, points, order_id)
SELECT o.store_id,
       left(regexp_replace(o.phone, '[^0-9]', '', 'g'), 2) || right(regexp_replace(o.phone, '[^0-9]', '', 'g'), 8),
       'ganho',
       (floor(o.total / 15) + CASE WHEN o.total - floor(o.total / 15) * 15 >= 11 THEN 1 ELSE 0 END)::int,
       o.id
  FROM orders o
 WHERE o.origin IN ('WEB', 'APP')
   AND o.status <> 'Cancelado'
   AND o.phone IS NOT NULL
   AND length(regexp_replace(o.phone, '[^0-9]', '', 'g')) >= 10
   AND o.total >= 11
   AND NOT EXISTS (SELECT 1 FROM loyalty_points_ledger l WHERE l.order_id = o.id AND l.tipo = 'ganho')
ON CONFLICT (order_id) WHERE tipo = 'ganho' AND order_id IS NOT NULL DO NOTHING;

INSERT INTO loyalty_points_ledger (store_id, phone, tipo, points, order_id)
SELECT l.store_id, l.phone, 'estorno', -l.points, l.order_id
  FROM loyalty_points_ledger l
  JOIN orders o ON o.id = l.order_id
 WHERE l.tipo = 'ganho'
   AND o.status = 'Cancelado'
   AND NOT EXISTS (SELECT 1 FROM loyalty_points_ledger e WHERE e.order_id = l.order_id AND e.tipo = 'estorno')
ON CONFLICT (order_id) WHERE tipo = 'estorno' AND order_id IS NOT NULL DO NOTHING;

-- reconstroi os saldos de novo
INSERT INTO customer_loyalty_points (store_id, phone, points_balance, updated_at)
SELECT store_id, phone, GREATEST(0, SUM(points))::int, now()
  FROM loyalty_points_ledger
 GROUP BY store_id, phone
ON CONFLICT (store_id, phone)
DO UPDATE SET points_balance = EXCLUDED.points_balance, updated_at = now();

COMMIT;
