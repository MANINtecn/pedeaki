-- Corrige a config de DDD padrao da loja.
-- CORRECAO 21/09/2026: a analise anterior (mesma sessao) errou ao concluir
-- que o Acai do Dudu era Tocantins (DDD 63). O Ikarus confirmou que a loja
-- E' de Minas Gerais mesmo -- DDD 32 estava certo desde o inicio.
--
-- O bug real nao era o DDD errado: era o app nao ter uma normalizacao capaz
-- de tratar as 4 formas que um cliente pode digitar o mesmo numero
-- (com/sem DDD, com/sem o 9o digito movel) como o MESMO cadastro. Isso foi
-- corrigido no codigo (funcao `canonicalPhone` em supabaseService.ts).
--
-- Esta coluna so formaliza no banco qual e' o DDD padrao a assumir quando o
-- cliente digita o numero SEM DDD nenhum (8-9 digitos apenas).

ALTER TABLE settings ADD COLUMN IF NOT EXISTS default_ddd TEXT DEFAULT '32';

UPDATE settings SET default_ddd = '32' WHERE store_id = '0ba99172-9964-4d1e-87e4-f36df362eb1c';
