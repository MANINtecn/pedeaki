-- PIX + envio do comprovante pelo WhatsApp.
--
-- Ao fechar um pedido com PIX, o cliente vê a chave, o aviso de que o pedido já
-- entrou em produção, e um botão que abre o WhatsApp da loja com o resumo do
-- pedido já escrito — ele só anexa o comprovante.

ALTER TABLE settings ADD COLUMN IF NOT EXISTS pix_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS pix_key TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS pix_key_type TEXT DEFAULT 'CNPJ';
ALTER TABLE settings ADD COLUMN IF NOT EXISTS pix_beneficiary TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS store_whatsapp TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS pix_resumo_template TEXT;

-- pix_enabled        : liga/desliga a tela pós-pedido
-- pix_key            : a chave (ex.: 44344954000197)
-- pix_key_type       : CNPJ | CPF | Celular | E-mail | Aleatória
-- pix_beneficiary    : nome que o cliente confere antes de pagar
-- store_whatsapp     : número que recebe o comprovante (só dígitos, com DDD)
-- pix_resumo_template: modelo do resumo; vazio = usa o padrão do sistema
