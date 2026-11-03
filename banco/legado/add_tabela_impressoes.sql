-- Trava de impressão duplicada — no BANCO, não na memória.
--
-- POR QUE: o pedido saía 2x mesmo com UMA só máquina. O realtime e o polling
-- disparam o mesmo pedido, e as travas em memória (`currentlyPrintingIds`,
-- `printedOrderIds`) têm uma janela: entre checar e marcar, o segundo gatilho
-- passa. E memória não atravessa máquinas.
--
-- COM A CHAVE ÚNICA o próprio Postgres recusa a segunda inserção. A garantia
-- deixa de depender do código acertar o tempo.
--
-- Bônus: fica o rastro de o que foi impresso, onde e quando.

CREATE TABLE IF NOT EXISTS impressoes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  store_id    uuid NOT NULL,
  estacao     text NOT NULL,          -- nome da máquina (estacaoService.nome) ou 'default'
  tipo_via    text NOT NULL,          -- 'principal' | 'cozinha' | 'bar' | 'entregador'
  impresso_em timestamptz NOT NULL DEFAULT now(),

  -- O coração da solução: a mesma via não sai duas vezes na mesma estação.
  CONSTRAINT impressoes_unicas UNIQUE (order_id, estacao, tipo_via)
);

CREATE INDEX IF NOT EXISTS impressoes_order_idx ON impressoes (order_id);
CREATE INDEX IF NOT EXISTS impressoes_store_data_idx ON impressoes (store_id, impresso_em DESC);

ALTER TABLE impressoes ENABLE ROW LEVEL SECURITY;

-- ⚠️ O "TO public" e OBRIGATORIO. Sem ele a politica nao alcanca o papel anon
-- que o app usa, e todo INSERT volta com
-- "new row violates row-level security policy" — a trava fica inutil.
-- Mesmo padrao das policies de `orders` (ver fix_orders_rls.sql).
DROP POLICY IF EXISTS impressoes_acesso ON impressoes;
DROP POLICY IF EXISTS "Public All Impressoes" ON impressoes;

CREATE POLICY "Public All Impressoes" ON public.impressoes
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- Consultas úteis:
--   o que foi impresso hoje e por qual máquina
-- SELECT estacao, tipo_via, count(*) FROM impressoes
-- WHERE impresso_em::date = CURRENT_DATE GROUP BY 1,2;
--
--   pedidos que saíram mais de uma vez (não deve retornar nada)
-- SELECT order_id, estacao, tipo_via, count(*) FROM impressoes
-- GROUP BY 1,2,3 HAVING count(*) > 1;
