-- Preenchimento fiscal dos ultimos 14 produtos pendentes (NCM enviado pelo
-- contador em 28/09/2026). CFOP/CSOSN aplicados pela MESMA regra ja
-- confirmada no lote anterior (fill_fiscal_produtos.sql, 21/09/2026):
--   - producao propria da loja (comida feita na casa) = CSOSN 102 / CFOP 5102
--   - industrializado/revenda pronta = CSOSN 500 / CFOP 5405 (Substituicao Tributaria)
--
-- CEST: contador respondeu em 28/09/2026 (segunda pergunta, so os 5 NCMs
-- novos). Ele mandou os codigos com pontuacao (ex: "17.051.00") -- gravado
-- aqui SEM pontos, 7 digitos corridos, mesmo formato usado no lote anterior
-- (0300505, 0301001) e exigido no XML da NFC-e.
--   19052090 (bolo)              -> CEST 1705100
--   17049020 (halls/fini/sonho)  -> SEM CEST, confirmado pelo contador (NULL)
--   21069090 (batata recheada)   -> CEST 1704802
--   21069029 (acai 10L)          -> CEST 2300100
--   18069000 (ovo recheado)      -> CEST 1709400
-- Agua mineral e Agua Tonica ja tinham CEST reaproveitado do lote anterior.

UPDATE menu_items SET ncm = '19052090', cest = '1705100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 304; -- bolo de brigadeiro
UPDATE menu_items SET ncm = '19052090', cest = '1705100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 305; -- bolo de ninho
UPDATE menu_items SET ncm = '19052090', cest = '1705100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 306; -- bolo de prestigio

UPDATE menu_items SET ncm = '17049020', cest = NULL, cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 325; -- halls extra forte
UPDATE menu_items SET ncm = '17049020', cest = NULL, cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 326; -- halls cereja
UPDATE menu_items SET ncm = '17049020', cest = NULL, cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 323; -- fini tubes morango
UPDATE menu_items SET ncm = '17049020', cest = NULL, cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 324; -- chocolate sonho de valsa 25 gramas
UPDATE menu_items SET ncm = '17049020', cest = NULL, cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 302; -- chocolate com marshmallon 480ml (feito na casa, quente)

UPDATE menu_items SET ncm = '21069090', cest = '1704802', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 262; -- Batata recheada (500gr)

UPDATE menu_items SET ncm = '21069029', cest = '2300100', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 268; -- Açaí 10 litros

UPDATE menu_items SET ncm = '22011000', cest = '0300505', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 310; -- Água mineral (sem gás)

UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 318; -- Água Tônica 350ml

UPDATE menu_items SET ncm = '18069000', cest = '1709400', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 328; -- ovo recheado (100g + 2 bolas)
UPDATE menu_items SET ncm = '18069000', cest = '1709400', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 329; -- ovo recheado (100g + 1 bola)
