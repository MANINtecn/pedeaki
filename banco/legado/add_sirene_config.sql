-- Alerta sonoro de pedido novo: som e volume configuráveis.
--
-- POR QUE: o som vinha de uma URL externa (mixkit.co) com volume fixo em 0.8.
-- Ficava baixo para a cozinha e, pior, **dependia de internet** — se a conexão
-- caísse o alerta não tocava e o pedido passava despercebido.
-- Agora o som é gerado no próprio app (WebAudio), funciona offline e o volume
-- vai além do que um <audio> permite.

ALTER TABLE settings
ADD COLUMN IF NOT EXISTS sirene_tipo TEXT DEFAULT 'sino';

ALTER TABLE settings
ADD COLUMN IF NOT EXISTS sirene_volume INTEGER DEFAULT 3;

-- Lojas já existentes ficam no padrão.
UPDATE settings SET sirene_tipo   = 'sino' WHERE sirene_tipo   IS NULL;
UPDATE settings SET sirene_volume = 3      WHERE sirene_volume IS NULL;

-- sirene_tipo: 'sino' | 'alarme' | 'campainha'
-- sirene_volume: 1 a 10 (3 = normal; acima disso o som é amplificado)
