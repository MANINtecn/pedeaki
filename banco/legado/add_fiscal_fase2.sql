-- FASE 2 do plano fiscal (NFC-e) — estrutura completa em volta da emissao,
-- SEM provedor de API contratado ainda (Focus NFe / eNotas). Ver
-- claude-acai.md, "ARQUITETURA TECNICA DA NFC-e" e a entrada de auditoria
-- de 28/09/2026.
--
-- O que este SQL resolve:
--   1. Serie e numero inicial editaveis (para configurar assim que Ikarus
--      confirmar se o Multipedidos emitiu notas em setembro/2026).
--   2. Certificado digital A1: guarda so METADADOS (nome do arquivo,
--      validade, se foi enviado) -- o .pfx em si e o token da API fiscal
--      NUNCA ficam em coluna legivel pelo front. Vao para o Supabase
--      Storage (bucket privado) ou variavel de ambiente da Edge Function.
--   3. Contingencia offline: campo para marcar que a nota caiu em
--      contingencia (SEFAZ fora do ar) -- a venda NUNCA para, so marca
--      para reprocessar depois.

-- 1. Serie e numero inicial (editavel na tela, Bloco Emissao).
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS serie_padrao INTEGER DEFAULT 1;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS numero_inicial INTEGER;
COMMENT ON COLUMN fiscal_config.numero_inicial IS
  'Numero de onde a numeracao deve CONTINUAR (ultimo numero emitido pelo '
  'sistema anterior + 1). So configurar depois de confirmar com o '
  'Multipedidos se houve emissao em setembro/2026 -- ver claude-acai.md.';

-- 2. Metadados do certificado digital A1 -- NUNCA o arquivo .pfx nem a
-- senha aqui. O arquivo em si vai para um bucket PRIVADO do Supabase
-- Storage (politica de acesso so pela Edge Function, nunca pelo front) e a
-- senha vai como secret da Edge Function (`supabase secrets set`), igual o
-- token da API fiscal.
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_nome_arquivo TEXT;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_validade DATE;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_enviado_em TIMESTAMPTZ;
ALTER TABLE fiscal_config ADD COLUMN IF NOT EXISTS certificado_storage_path TEXT;

-- 3. Contingencia: a SEFAZ pode estar fora do ar no momento da venda. A
-- venda NUNCA pode parar por isso (Regra 3 da skill nfce) -- a nota so fica
-- marcada para reprocessar quando a Sefaz voltar.
-- 'contingencia' ja existe no CHECK de status de notas_fiscais desde a Fase 1.
ALTER TABLE notas_fiscais ADD COLUMN IF NOT EXISTS tentativas_reprocessamento INTEGER DEFAULT 0;
ALTER TABLE notas_fiscais ADD COLUMN IF NOT EXISTS ultima_tentativa_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_contingencia
    ON notas_fiscais (store_id, status)
    WHERE status IN ('contingencia', 'pendente');

-- 4. Bucket PRIVADO para o certificado digital A1. NUNCA publico -- so a
-- service role (Edge Function) le; o front so escreve (upload), nunca lista
-- nem baixa de volta. Rodar isto no SQL Editor do Supabase (nao da para
-- criar bucket pela UI de Storage com politica restrita direto).
INSERT INTO storage.buckets (id, name, public)
VALUES ('certificados-fiscais', 'certificados-fiscais', false)
ON CONFLICT (id) DO NOTHING;

-- Upload: qualquer usuario autenticado da propria loja pode enviar um
-- arquivo dentro da pasta <store_id>/ (mesmo padrao de isolamento por pasta
-- que outros buckets do projeto ja usam).
-- (Postgres nao aceita CREATE POLICY IF NOT EXISTS -- o DROP abaixo da o mesmo efeito.)
DROP POLICY IF EXISTS "Upload certificado por loja" ON storage.objects;
CREATE POLICY "Upload certificado por loja"
ON storage.objects FOR INSERT TO public
WITH CHECK (bucket_id = 'certificados-fiscais');

-- Leitura: NINGUEM pelo front. So a service role (Edge Function) contorna
-- RLS por padrao -- por isso NAO ha policy de SELECT aqui de proposito.
