-- Separa o auto-print de Retirada do auto-print de Mesa. Ate 21/09/2026 os
-- dois caiam na mesma coluna (auto_print_dine_in), entao desligar pensando
-- so em Mesa tambem desligava Retirada sem o Ikarus perceber -- foi
-- exatamente o que aconteceu (o valor de auto_print_dine_in ja estava
-- false, então Retirada tambem parou de imprimir sozinho).
--
-- Default TRUE: Retirada volta a imprimir automaticamente, independente do
-- que estiver configurado para Mesa.
ALTER TABLE settings ADD COLUMN IF NOT EXISTS auto_print_retirada BOOLEAN DEFAULT true;

UPDATE settings SET auto_print_retirada = true WHERE auto_print_retirada IS NULL;
