-- FASE 1 do plano fiscal (NFC-e) — ver claude-acai.md, "ARQUITETURA TECNICA DA NFC-e".
-- So schema/config. NAO emite nota nenhuma sozinho — isso e a Fase 2
-- (Edge Function), que so entra depois de escolhida a API fiscal.
--
-- Os valores DEFAULT abaixo (CFOP 5101, CSOSN 102, PIS/COFINS 07) sao os
-- ja levantados com o contador para o Acai do Dudu especificamente — nao
-- sao genericos. Confirmar contra o XML real assim que o Ikarus trouxer.

-- 1. Configuracao fiscal da loja (1 linha por loja).
CREATE TABLE IF NOT EXISTS fiscal_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL UNIQUE REFERENCES stores(id) ON DELETE CASCADE,

    -- Identificacao da empresa perante a SEFAZ
    cnpj TEXT,
    inscricao_estadual TEXT,
    razao_social TEXT,
    nome_fantasia TEXT,

    -- Endereco (exigido no XML da NFC-e)
    logradouro TEXT,
    numero TEXT,
    bairro TEXT,
    municipio TEXT,
    cod_ibge_municipio TEXT,
    uf TEXT DEFAULT 'TO',
    cep TEXT,

    -- Regime tributario. CRT=1 = Simples Nacional (confirmado com o contador).
    regime_tributario SMALLINT DEFAULT 1,
    cfop_padrao TEXT DEFAULT '5101',
    csosn_padrao TEXT DEFAULT '102',
    pis_cst TEXT DEFAULT '07',
    cofins_cst TEXT DEFAULT '07',
    carga_tributaria_aprox NUMERIC(5,2) DEFAULT 4.00,

    -- Ambiente: NUNCA 'producao' por engano em teste.
    ambiente TEXT NOT NULL DEFAULT 'homologacao' CHECK (ambiente IN ('homologacao', 'producao')),

    -- Provedor da API fiscal (Focus NFe / TecnoSpeed / Webmania — a decidir).
    -- ⚠️ O TOKEN NUNCA E LIDO PELO FRONT. So a Edge Function (Fase 2) o le,
    -- via variavel de ambiente do proprio Supabase — NAO fica em coluna
    -- alguma que o app Electron consiga consultar. Esta coluna existe so
    -- para o painel admin mostrar QUAL provedor esta configurado, nunca o
    -- valor do token.
    provedor_api TEXT,

    -- Credenciais NFC-e da SEFAZ-TO (CSC = Codigo de Seguranca do
    -- Contribuinte, usado no QR Code — diferente do certificado digital).
    csc_id TEXT,
    csc_token TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE fiscal_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public All FiscalConfig" ON public.fiscal_config
FOR ALL TO public USING (true) WITH CHECK (true);

-- 2. Colunas fiscais por produto (menu_items).
-- NCM e OBRIGATORIO por produto para emitir — 33 dos 73 produtos do Acai
-- ainda estao sem, segundo o levantamento de 09/09. Nulo aqui ATE o
-- contador definir; a tela de emissao (Fase 2) deve bloquear item sem NCM.
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS ncm TEXT;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS cest TEXT;
-- 'UN' e o padrao; o acai vendido por peso usa 'KG' (3 casas decimais na nota).
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS unidade_fiscal TEXT DEFAULT 'UN';
-- Origem da mercadoria: 0 = nacional (padrao SEFAZ para produto de sorveteria).
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS origem_fiscal SMALLINT DEFAULT 0;

-- 3. Notas fiscais emitidas — o coracao do relatorio (Fase 3) e do controle
-- de status (Fase 2). Serie por MAQUINA (salao=1, cozinha=2), decisao ja
-- fechada com o Ikarus em 09/09 — evita duas maquinas caindo no mesmo
-- numero e a SEFAZ rejeitando por duplicidade.
CREATE TABLE IF NOT EXISTS notas_fiscais (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,

    serie INTEGER NOT NULL,
    numero INTEGER NOT NULL,
    chave_acesso TEXT,          -- 44 digitos, so preenchido apos autorizada
    protocolo_autorizacao TEXT,

    status TEXT NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente', 'autorizada', 'rejeitada', 'cancelada', 'contingencia')),
    motivo_rejeicao TEXT,

    valor_total NUMERIC(10,2) NOT NULL,
    data_emissao TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- XML cabe em ~4-8 KB, sem problema em coluna text. Se um dia pesar
    -- (ex.: notas com muitos itens), migrar para Supabase Storage.
    xml TEXT,
    danfe_url TEXT,

    emitida_por_estacao TEXT,   -- nome da maquina (ver estacaoService.ts)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Nunca duas notas com a mesma serie+numero na mesma loja — e a regra
    -- que a SEFAZ exige (numeracao sequencial sem buraco, POR SERIE).
    UNIQUE (store_id, serie, numero)
);

CREATE INDEX IF NOT EXISTS idx_notas_fiscais_store_status
    ON notas_fiscais (store_id, status);
CREATE INDEX IF NOT EXISTS idx_notas_fiscais_order
    ON notas_fiscais (order_id);

ALTER TABLE notas_fiscais ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public All NotasFiscais" ON public.notas_fiscais
FOR ALL TO public USING (true) WITH CHECK (true);
