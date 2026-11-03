
-- Adiciona colunas para controle de impressoras secundárias e compatibilidade
ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS kitchen_printer TEXT,
ADD COLUMN IF NOT EXISTS kitchen_printer_paper_width TEXT DEFAULT '58mm',
ADD COLUMN IF NOT EXISTS bar_printer TEXT,
ADD COLUMN IF NOT EXISTS bar_printer_paper_width TEXT DEFAULT '58mm',
ADD COLUMN IF NOT EXISTS courier_printer TEXT,
ADD COLUMN IF NOT EXISTS courier_printer_paper_width TEXT DEFAULT '58mm',
ADD COLUMN IF NOT EXISTS printer_compatibility_mode BOOLEAN DEFAULT FALSE;

-- Opcional: Atualizar para garantir que as novas colunas tenham valores padrão para linhas existentes
UPDATE settings SET kitchen_printer_paper_width = '58mm' WHERE kitchen_printer_paper_width IS NULL;
UPDATE settings SET bar_printer_paper_width = '58mm' WHERE bar_printer_paper_width IS NULL;
UPDATE settings SET courier_printer_paper_width = '58mm' WHERE courier_printer_paper_width IS NULL;
UPDATE settings SET printer_compatibility_mode = FALSE WHERE printer_compatibility_mode IS NULL;
