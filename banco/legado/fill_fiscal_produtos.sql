-- Preenchimento fiscal em lote (NCM/CEST/CFOP/CSOSN) por produto.
-- Fonte: cruzamento dos 822 XMLs reais do Multipedidos com o cardapio atual,
-- 21/09/2026. CFOP/CSOSN por produto (nao mais so o padrao unico da loja)
-- confirmado com o contador (CS Contabilidade, 21/09/2026: "sim, correto").
--
-- 59 de 73 produtos cobertos aqui (35 com nome identico a um XML real, 24
-- pela mesma familia fiscal de um produto confirmado). Os 14 restantes NAO
-- entram aqui -- ver "fiscal_pendente_contador.md" / claude-acai.md:
--   - 12 nunca apareceram nos XMLs reais (bolo, halls, fini tubes, sonho de
--     valsa, chocolate c/ marshmallow, batata recheada, Acai 10 litros,
--     Agua mineral, Agua Tonica).
--   - 2 sao produtos compostos com ingredientes de regimes diferentes (Ovo
--     recheado, mistura sorvete+açai) -- ambiguo demais para classificar
--     sozinho, precisa do contador.
--
-- Rode primeiro este bloco (cria as colunas), depois o restante do arquivo:
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS cfop_fiscal TEXT;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS csosn_fiscal TEXT;


UPDATE menu_items SET ncm = '19022000', cest = '1704802', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 261; -- 10 unid salgados ( porçao)
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 267; -- Açaí  pote familia 1.8lts
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 266; -- Açaí - 1000ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 264; -- Açaí - 350ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 265; -- Açaí - 500ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 283; -- acai 140ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 263; -- açai 140ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 281; -- Acai 350ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 282; -- Acai 500ml
UPDATE menu_items SET ncm = '22011000', cest = '0300505', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 311; -- Água mineral com gás
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 294; -- Brownie com sorvete
UPDATE menu_items SET ncm = '11022000', cest = '1703000', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 307; -- canjica de amendoin
UPDATE menu_items SET ncm = '11022000', cest = '1703000', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 308; -- canjica de coco
UPDATE menu_items SET ncm = '11022000', cest = '1703000', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 309; -- canjica mista( amendoin e coco)
UPDATE menu_items SET ncm = '19022000', cest = '1704802', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 299; -- churros doce de leite
UPDATE menu_items SET ncm = '19022000', cest = '1704802', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 301; -- churros doce misto
UPDATE menu_items SET ncm = '19022000', cest = '1704802', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 300; -- churros nutella
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 312; -- coca cola 2 l
UPDATE menu_items SET ncm = '18063210', cest = '1700300', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 297; -- Fondue chocolate ao leite
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 291; -- Milk Shake 500ml
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 292; -- Milk Shake Gourmet Ferrero Rocher 500ml
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 257; -- milk shake mousse de uva com limao 500ml
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 295; -- Petit gateau  com sorvete
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 280; -- picole casquinha
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 278; -- Picolés Gourmet
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 279; -- Picolés Tradicionais
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 275; -- Potes de Sorvete 1,8L
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 276; -- sorvete 1,8ls + cascão
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 277; -- sorvete 1,8lts + cascão + calda
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 271; -- Sorvete flocos
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 269; -- Sorvete morango
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 272; -- Sorvete ninho com morango
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 273; -- Sorvete ninho trufado
UPDATE menu_items SET ncm = '22029900', cest = '0301302', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 293; -- vitamina acai
UPDATE menu_items SET ncm = '22029900', cest = '0301302', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 284; -- Vitamina açaí
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 285; -- acai fammilia 1.8lts
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 288; -- acai zero 350ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 289; -- açai zero 500ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 286; -- açai zero puro 2000ml
UPDATE menu_items SET ncm = '20079921', cest = '1709400', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 287; -- açai zero puro 220ml
UPDATE menu_items SET ncm = '22011000', cest = '0300505', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 319; -- agua de coco 450ml
UPDATE menu_items SET ncm = '18063210', cest = '1700300', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 303; -- chocolate 300ml
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 317; -- coca cola 200ml
UPDATE menu_items SET ncm = '18063210', cest = '1700300', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 296; -- Fondue chocolate branco
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 321; -- gatorade laranja
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 322; -- gatorade uva
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 314; -- guarana 200ml
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 313; -- guarana 2lts
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 258; -- milk shake rafaello 500ml
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 260; -- Milk-shake cafe c nutella 500ml
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 259; -- Milk-shake laka 500ml
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 315; -- pepsi  200ml
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 316; -- pepsi 200ml black
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5102', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 290; -- picole zero de morango
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 274; -- Sorvete leite condensado
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 270; -- Sorvete nutella
UPDATE menu_items SET ncm = '21050010', cest = '2300100', cfop_fiscal = '5101', csosn_fiscal = '102', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 327; -- sorvete self service
UPDATE menu_items SET ncm = '22021000', cest = '0301001', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 320; -- SUCO TIAL 330ML GOIABA
UPDATE menu_items SET ncm = '22029900', cest = '0301302', cfop_fiscal = '5405', csosn_fiscal = '500', unidade_fiscal = COALESCE(unidade_fiscal, 'UN'), origem_fiscal = COALESCE(origem_fiscal, 0) WHERE id = 298; -- vitamina de whey protein 500ml
