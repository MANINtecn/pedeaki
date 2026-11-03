-- 1. Adicionar coluna opening_hours na tabela stores
ALTER TABLE stores 
ADD COLUMN IF NOT EXISTS opening_hours JSONB DEFAULT '{
  "sunday": {"open": "18:00", "close": "23:00", "isOpen": true},
  "monday": {"open": "18:00", "close": "23:00", "isOpen": true},
  "tuesday": {"open": "18:00", "close": "23:00", "isOpen": false},
  "wednesday": {"open": "18:00", "close": "23:00", "isOpen": true},
  "thursday": {"open": "18:00", "close": "23:00", "isOpen": true},
  "friday": {"open": "18:00", "close": "23:00", "isOpen": true},
  "saturday": {"open": "18:00", "close": "23:00", "isOpen": true}
}';

-- 2. Função para verificar se a loja está aberta (Para o AI N8N)
CREATE OR REPLACE FUNCTION check_store_open(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_hours JSONB;
  v_day_key TEXT;
  v_now TIMESTAMP WITH TIME ZONE;
  v_current_time TIME;
  v_open_time TIME;
  v_close_time TIME;
  v_is_day_open BOOLEAN;
BEGIN
  -- Data e Hora atual no Brasil
  v_now := NOW() AT TIME ZONE 'America/Sao_Paulo';
  v_current_time := v_now::TIME;
  
  -- Dia da semana (em inglês minúsculo para bater com o JSON)
  v_day_key := TRIM(LOWER(TO_CHAR(v_now, 'Day')));

  -- Buscar configurações da loja
  SELECT opening_hours INTO v_hours
  FROM stores
  WHERE id = p_store_id;

  -- Se não tiver configuração, assume aberto (fallback)
  IF v_hours IS NULL THEN
    RETURN jsonb_build_object('isOpen', true, 'message', 'Loja aberta (sem config).');
  END IF;

  -- Extrair dados do dia
  v_is_day_open := (v_hours->v_day_key->>'isOpen')::BOOLEAN;
  v_open_time := (v_hours->v_day_key->>'open')::TIME;
  v_close_time := (v_hours->v_day_key->>'close')::TIME;

  -- Verificações
  IF v_is_day_open IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'isOpen', false, 
      'message', 'Olá! Hoje não abrimos. Nosso horário é de ' || v_open_time || ' às ' || v_close_time || '.'
    );
  END IF;

  IF v_current_time < v_open_time OR v_current_time > v_close_time THEN
    RETURN jsonb_build_object(
      'isOpen', false, 
      'message', 'Olá! Agora estamos fechados. Nosso horário hoje é das ' || TO_CHAR(v_open_time, 'HH24:MI') || ' às ' || TO_CHAR(v_close_time, 'HH24:MI') || '.'
    );
  END IF;

  RETURN jsonb_build_object('isOpen', true, 'message', 'Loja aberta.');
END;
$$;
