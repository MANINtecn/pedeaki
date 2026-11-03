-- Função para buscar histórico como TEXTO (para injetar no Prompt do N8N)
CREATE OR REPLACE FUNCTION get_chat_history_string(p_phone text)
RETURNS text AS $$
DECLARE
    result text := '';
    r record;
BEGIN
    -- Busca as últimas 30 mensagens da sessão (Proteção contra estouro de memória)
    -- A lógica é: Pega as 30 mais recentes (DESC) e depois reordena para cronológico (ASC)
    FOR r IN (
        SELECT * FROM (
            SELECT message, created_at
            FROM chat_histories 
            WHERE session_id = (p_phone || '-v1') 
            ORDER BY created_at DESC
            LIMIT 50
        ) sub
        ORDER BY created_at ASC
    )
    LOOP
        -- Se for mensagem do HUMANO
        IF r.message->>'type' = 'human' THEN
            result := result || 'Cliente: ' || (r.message->>'content') || E'\n';
        -- Se for mensagem da IA
        ELSIF r.message->>'type' = 'ai' THEN
            result := result || 'Você (IA): ' || (r.message->>'content') || E'\n';
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para SALVAR mensagem (chamada pelo N8N via API)
CREATE OR REPLACE FUNCTION add_chat_msg(p_phone text, p_role text, p_content text)
RETURNS void AS $$
BEGIN
    INSERT INTO chat_histories (session_id, message)
    VALUES (
        (p_phone || '-v1'),
        jsonb_build_object('type', p_role, 'content', p_content)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
