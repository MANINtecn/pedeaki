-- NFC-e: cadastro da empresa no Brasil NFe pelo proprio app.
-- SUBSTITUI o add_fiscal_fase2.sql (inclui tudo dele). Tudo aditivo e com
-- IF NOT EXISTS: pode rodar mais de uma vez e nao mexe em dado existente.

-- 1. Serie, numero inicial e metadados do certificado (da fase 2)
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS serie_padrao INTEGER DEFAULT 1;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS numero_inicial INTEGER;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_nome_arquivo TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_validade DATE;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_enviado_em TIMESTAMPTZ;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_storage_path TEXT;

-- 2. Campos que o cadastro do Brasil NFe aceita e faltavam
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS inscricao_municipal TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS cnae TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS telefone TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS complemento TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS csc_id_homologacao TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS brasilnfe_cadastrada_em TIMESTAMPTZ;

COMMENT ON COLUMN fiscal_config.csc_token IS
  'LEGADO: o CSC nao e mais guardado aqui. Vai direto ao Brasil NFe no cadastro e a funcao limpa este campo.';

-- 3. Contingencia / reprocessamento
ALTER TABLE notas_fiscais ADD COLUMN IF NOT EXISTS tentativas_reprocessamento INTEGER DEFAULT 0;
ALTER TABLE notas_fiscais ADD COLUMN IF NOT EXISTS ultima_tentativa_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_contingencia
    ON notas_fiscais (store_id, status)
    WHERE status IN ('contingencia', 'pendente');

-- 4. Token da empresa no Brasil NFe, 1 linha por loja. RLS ligado SEM
-- nenhuma policy e sem permissao para anon/authenticated: o app instalado
-- nao le nem escreve aqui. So as Edge Functions (service role) acessam.
CREATE TABLE IF NOT EXISTS fiscal_credenciais (
    store_id UUID PRIMARY KEY REFERENCES stores(id) ON DELETE CASCADE,
    brasilnfe_token_empresa TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE fiscal_credenciais ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON fiscal_credenciais FROM anon, authenticated;

-- 5. Bucket PRIVADO para o .pfx em transito. O app so envia (INSERT); NAO
-- existe policy de leitura. A Edge Function le, manda ao Brasil NFe e
-- apaga o arquivo logo depois.
INSERT INTO storage.buckets (id, name, public)
VALUES ('certificados-fiscais', 'certificados-fiscais', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Upload certificado por loja" ON storage.objects;
CREATE POLICY "Upload certificado por loja"
ON storage.objects FOR INSERT TO public
WITH CHECK (bucket_id = 'certificados-fiscais');
