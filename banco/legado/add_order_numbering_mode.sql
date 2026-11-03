-- Modo de numeracao de pedido configuravel por loja -- 28/09/2026.
-- Pedido do Ikarus: um botao nas Configuracoes para escolher se o numero
-- do pedido (#1, #2...) reinicia sozinho todo dia (como sempre foi) ou so'
-- quando o operador clicar em "Zerar numeracao agora" (contagem mensal).
--
-- Contexto: o trigger `set_daily_order_number` (ver unified_numbering_fix.sql)
-- ja calculava o proximo numero por dia, em horario de Brasilia -- correto,
-- mas fixo. Este SQL torna esse comportamento CONFIGURAVEL por loja.

-- 1. Colunas novas em settings.
ALTER TABLE settings ADD COLUMN IF NOT EXISTS order_numbering_mode TEXT NOT NULL DEFAULT 'diario'
    CHECK (order_numbering_mode IN ('diario', 'mensal'));
ALTER TABLE settings ADD COLUMN IF NOT EXISTS order_numbering_reset_at TIMESTAMPTZ;

COMMENT ON COLUMN settings.order_numbering_mode IS
  'diario = numero do pedido reinicia sozinho toda meia-noite (America/Sao_Paulo). '
  'mensal = NUNCA reinicia sozinho, so quando order_numbering_reset_at for atualizado '
  '(botao "Zerar numeracao agora" nas Configuracoes).';

-- 2. Trigger atualizado: le o modo da loja antes de decidir o corte.
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_num INTEGER;
  v_modo TEXT;
  v_reset_at TIMESTAMPTZ;
BEGIN
  IF NEW.daily_order_number IS NULL OR NEW.daily_order_number = 0 THEN

      SELECT order_numbering_mode, order_numbering_reset_at
      INTO v_modo, v_reset_at
      FROM settings
      WHERE store_id = NEW.store_id;

      IF v_modo = 'mensal' THEN
          -- Conta TODOS os pedidos desde o ultimo reset manual (ou desde
          -- sempre, se nunca zerou). Nao reinicia sozinho por data.
          SELECT COALESCE(MAX(daily_order_number), 0) + 1
          INTO next_num
          FROM orders
          WHERE store_id = NEW.store_id
            AND (v_reset_at IS NULL OR timestamp >= v_reset_at);
      ELSE
          -- Modo 'diario' (padrao) -- comportamento historico, sem mudanca:
          -- reinicia toda meia-noite em horario de Brasilia.
          SELECT COALESCE(MAX(daily_order_number), 0) + 1
          INTO next_num
          FROM orders
          WHERE store_id = NEW.store_id
            AND date(timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo') =
                date(NEW.timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo');
      END IF;

      NEW.daily_order_number := next_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger em si ja existe (trigger_set_daily_order_number), so a FUNCTION
-- mudou -- CREATE OR REPLACE acima ja e' suficiente, nao precisa recriar o
-- trigger.
