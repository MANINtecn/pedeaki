-- Foto grande da tela inicial (landing) da versao Moderna do site do cliente.
-- Vazio/NULL = continua usando o arquivo padrao /acai_boat_hero.jpg.
ALTER TABLE settings ADD COLUMN IF NOT EXISTS hero_image_url TEXT;
