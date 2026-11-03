-- Mini-colinha de atalhos durante o lancamento no balcao.
-- Mostra, em tempo real, so as teclas que valem no passo atual.
-- Desligavel depois que a equipe aprender.

ALTER TABLE settings
ADD COLUMN IF NOT EXISTS mostrar_dicas_atalho BOOLEAN DEFAULT TRUE;

UPDATE settings SET mostrar_dicas_atalho = TRUE WHERE mostrar_dicas_atalho IS NULL;
