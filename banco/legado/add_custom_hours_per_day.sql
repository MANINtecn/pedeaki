-- Horario personalizado por dia da semana -- 28/09/2026.
-- Pedido do Ikarus: sexta/sabado (ou qualquer dia) com horario diferente
-- do padrao openingTime/closingTime.
--
-- Formato: {"5": {"open": "19:00", "close": "01:00"}, "6": {"open": "19:00", "close": "02:00"}}
-- Chave = indice do dia (0=Dom .. 6=Sab, mesmo padrao de days_of_week).
-- Dia SEM entrada aqui usa opening_time/closing_time normalmente -- nao
-- quebra nenhuma loja que ja usa o horario unico de sempre.

ALTER TABLE settings ADD COLUMN IF NOT EXISTS custom_hours_per_day JSONB DEFAULT '{}';

COMMENT ON COLUMN settings.custom_hours_per_day IS
  'Horario personalizado por dia da semana. Chave = indice do dia '
  '(0=Domingo..6=Sabado). Dia ausente usa opening_time/closing_time padrao.';
