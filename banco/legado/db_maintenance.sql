-- TABELA DE ESTATÍSTICAS DIÁRIAS (A 'Ideia Melhor')
-- Armazena o resumo do dia para que você possa apagar os pedidos brutos sem perder os dados importantes para análise (quem entregou mais, etc).
CREATE TABLE IF NOT EXISTS courier_daily_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    courier_id UUID REFERENCES couriers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_deliveries INTEGER DEFAULT 0,
    total_amount NUMERIC(10,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(courier_id, date) -- Segura que só tem um resumo por motoboy por dia
);

-- FUNÇÃO PARA CONSOLIDAR OS DADOS DO DIA
-- Essa função lê os pedidos 'Entregue' de um dia específico e salva o resumo na tabela acima.
CREATE OR REPLACE FUNCTION consolidate_courier_stats(target_date DATE)
RETURNS VOID AS $$
BEGIN
    INSERT INTO courier_daily_stats (courier_id, date, total_deliveries, total_amount)
    SELECT 
        courier_id, 
        target_date, 
        COUNT(*) as total_deliveries, 
        SUM(total) as total_amount
    FROM orders 
    WHERE 
        status = 'Entregue' 
        AND courier_id IS NOT NULL 
        AND DATE(timestamp) = target_date
    ON CONFLICT (courier_id, date) 
    DO UPDATE SET
        total_deliveries = EXCLUDED.total_deliveries,
        total_amount = EXCLUDED.total_amount;
END;
$$ LANGUAGE plpgsql;

-- FUNÇÃO QUE VOCÊ PEDIU (Limpeza)
-- Apaga pedidos entregues mais velhos que X dias.
-- Uso recomendado: Chamar SOMENTE se tiver certeza ou se já tiver consolidado os dados.
CREATE OR REPLACE FUNCTION purge_old_orders(days_to_keep INTEGER DEFAULT 60)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM orders
    WHERE 
        status = 'Entregue' 
        AND timestamp < NOW() - (days_to_keep || ' days')::INTERVAL
    RETURNING count(*) INTO deleted_count;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- FUNÇÃO MESTRE DE MANUTENÇÃO (Exemplo de uso)
-- Essa seria a função ideal para rodar num Cron Job todo dia a noite.
-- Ela consolida o dia anterior e limpa dados muito antigos.
CREATE OR REPLACE FUNCTION run_nightly_maintenance()
RETURNS VOID AS $$
BEGIN
    -- 1. Consolidar estatísticas de ontem (para garantir que o dia fechou)
    PERFORM consolidate_courier_stats(CURRENT_DATE - 1);
    
    -- 2. (Opcional) Limpar dados muito antigos (ex: manter 1 ano/365 dias online, o resto apaga)
    -- Sugestão: Aumentar de 60 para 365 dias. Banco de dados aguenta fácil e permite comparar "Novembro desse ano" vs "Novembro do ano passado".
    PERFORM purge_old_orders(730); 
END;
$$ LANGUAGE plpgsql;
