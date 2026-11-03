# Teste do Balcao V2 com o componente REAL (06/10/2026)

Monta o CounterTab de verdade num DOM falso (jsdom) com banco e balanca falsos e dispara teclas.
Reproduziu os 2 bugs de duplicata em comanda (reenvio fantasma + itens dobrando a cada Enter).

    cd scripts/teste-balcao && npm init -y && npm i jsdom@22      # uma vez (jsdom fica fora do projeto)
    # build.cjs usa o esbuild do projeto; ENTRY = arquivo de cenario, OUT = bundle, PROJSRC = src de outra versao
    ENTRY=g.tsx OUT=g.cjs node build.cjs && NODE_PATH=$PWD/node_modules node g.cjs     # comanda com 2 pedidos de mesmo item
    ENTRY=i.tsx OUT=i.cjs node build.cjs && NODE_PATH=$PWD/node_modules node i.cjs     # reenvio fantasma (Enter com handler velho)
    ENTRY=fuzz.tsx OUT=fuzz.cjs node build.cjs && N=30 SEED=1 NODE_PATH=$PWD/node_modules node fuzz.cjs

Esperado: g -> 1 item por comanda (e conserta a duplicata); i -> sempre 1 pedido; fuzz -> 0 problemas.
Para testar uma versao antiga: `git archive <commit> src | tar -x -C old` e PROJSRC=old/src.

## Adicionado em 15/10/2026 (segundo peso sumido, pedido #165)

    ENTRY=peso.tsx OUT=peso.cjs node build.cjs && NODE_PATH=$PWD/node_modules node peso.cjs          # P1-P5 (dois pesos + F7) e Q1-Q4 (F7 em fluxo normal)
    ENTRY=fechamento.ts OUT=fechamento.cjs node build.cjs && node fechamento.cjs                       # regra de fechamento (utils/fechamentoMesa.ts), 10 casos

- peso.tsx: o F7 e chamado FORA do `act` (como no app). Dentro de um `act` o React nao grava a tela e a conferencia le dado velho.
- P4 (peso lancado com o envio anterior em curso + F7) PERDIA o 2o peso na versao de 06/10 (trava envioUnico devolvia o resultado do envio velho ao F7).
- Esperado: peso.cjs -> FALHAS: 0 ; fechamento.cjs -> FALHAS: 0 ; g, i, fuzz continuam como antes.
- ATENCAO: `scripts/` esta no .gitignore do projeto -> esta pasta NAO vai para o git. Nao rodar `npm init`/`npm i` por cima sem olhar o conteudo da pasta (ja sobrescrevi o package.json uma vez).

## Balcao V2 OFFLINE (15/10/2026, versao 1.0.92)

    ENTRY=fila.ts OUT=fila.cjs node build.cjs && SEED=7 N=800 node fila.cjs                         # armazem + fila + envio, banco/disco falsos com falhas + fuzz com invariantes
    ENTRY=offline.tsx OUT=offline.cjs node build.cjs && NODE_PATH=$PWD/node_modules node offline.cjs   # CounterTab REAL no modo offline, banco falso a 3 s (F7 tem que fechar < 300 ms)

- fila.ts injeta: rede fora, resposta perdida, lentidao (timeout), venda recusada, banco sem a coluna `pagamentos`, disco falhando, reinicio do app no meio. Invariantes: toda venda fechada chega EXATAMENTE uma vez; nada chega sem ter sido fechado; total = itens - desconto + taxa = pagamentos; reiniciar devolve o mesmo estado; numeracao na ordem de fechamento.
- offline.tsx: o "AdminPage" de teste so faz o F7 com comanda aberta na tela (igual ao real).
- build.cjs: o stub do supabaseService agora tambem pega o `./supabaseService` importado de dentro de `services/` (comandaBackend.ts).
- Esperado: FALHAS: 0 nos dois. Rodar tambem g, i, fuzz, peso, fechamento (modo online = reserva).

## Bateria de PICO (15/10/2026, 1.0.93)

    ENTRY=pico.tsx OUT=pico.cjs node build.cjs && SESSOES=8 PASSOS=70 SEED=11 NODE_PATH=$PWD/node_modules node pico.cjs            # offline
    MODO=online SESSOES=6 PASSOS=60 SEED=5 NODE_PATH=$PWD/node_modules node pico.cjs                                               # V2 online (reserva), banco 30/150/600 ms
    PROJSRC=$PWD/old/src ENTRY=pico.tsx OUT=pico_prod.cjs node build.cjs   # mesma bateria contra outra versao (git archive <commit> src | tar -x -C old)
    TRACE=<sessao> ...                                                     # rastro passo a passo (tela, disco/banco, rascunhos, aviso)
    ENTRY=troca.tsx ... MODO=offline|online                                # troca rapida de comanda (X, C, numero) sem contaminar

- Juiz: modelo proprio do que foi lancado por comanda; confere a TELA depois de cada acao e a VENDA no F7/F8.
- Comportamento conhecido (nao e bug novo): apagar TODOS os itens de comanda ja salva e sair sem Enter (X, C, seta, numero) nao exclui; os itens voltam ao reabrir. O juiz acompanha isso.
- Resultado 15/10: offline 4 x 560 acoes = 0 problemas. Online: producao 1.0.90 = 208 problemas, 1.0.93 = 85 (3 x 360 acoes) -> V2 online segue fragil com internet lenta; o offline e a solucao.
- `@novo` (build.cjs) aponta sempre para o src atual; `@proj` pode ser outra versao (PROJSRC).

## Balanca automatica (19/10/2026, 1.0.94)

    ENTRY=balanca.tsx OUT=balanca.cjs node build.cjs && NODE_PATH=$PWD/node_modules node balanca.cjs   # 20 cenarios com a balanca falsa controlavel

- stub-scale.ts agora e controlavel: globalThis.__balanca.set(kg, estavel) / .desconectar() (testes antigos nao mudam: fica muda).
- Caso real: 18/10 19h16 comanda 5 (#415): troca direta de prato sem zerar -> Enter enviava. Na 1.0.93: 5 perdas silenciosas (S2, S3, S4, S6, S11). Na 1.0.94: 0 (19 OK + S8 "insistiu com peso oscilando" = regra com aviso).
- Regra nova em utils/pesoBalanca.ts (decidirEnterComBalanca, pratoFoiRetirado): peso que muda sem retirar o prato PERGUNTA (Enter outro prato / A atualizar / Esc ignorar); marca "ja lancado" por comanda; resto < metade do prato lancado = retirado.

## Caixa-preta + auditor (20/10/2026, 1.0.97)

    node auditar-diario.cjs "C:/Users/icaro/OneDrive/Área de Trabalho/diario-2026-10.jsonl" [AAAA-MM-DD]

- O diário passou a registrar: peso-na-tela (kg, id, estável), comanda-aberta (salvos / rascunho / tela), rascunho-salvo,
  balcao-saiu-com-pendente, item-removido-da-tela, fechamento-inicio (tela x salvos), e ids/itens em item-salvo,
  comanda-atualizada e venda-fechada.
- O auditor segue cada peso: vendido / apagado pela atendente / comanda excluída / em rascunho; o resto = PESO PERDIDO,
  com a linha do tempo da comanda (30 min antes, 60 min depois). Exit 1 se houver perda.
- aba.tsx com DIARIO_SAIDA=<arq> grava o diário dos cenários (16 pesos -> 13 vendidos, 1 apagado, 2 em rascunho, 0 perdidos).

## Investigacao "comandas ja enviadas" (20/10/2026)

    ENTRY=enviadas.tsx OUT=enviadas.cjs node build.cjs && SESSOES=6 PASSOS=70 SEED=1 NODE_PATH=$PWD/node_modules node enviadas.cjs
    PROJSRC=<copia do src com o CounterTab da 1.0.93> ENTRY=enviadas.tsx OUT=enviadas_193.cjs node build.cjs   # versao do sabado

- Balanca automatica usada do jeito certo, comandas enviadas e reabertas, lista atualizando sozinha (700 ms), SEM sair da aba.
- ATENCAO: o teste tem de importar armazem/backend de @proj (a MESMA arvore do CounterTab testado). Com @novo, a versao
  antiga escrevia num armazem e lia de outro -- deu 75-80 "falhas" falsas.
- Resultado: 1.0.93 = 0 problemas em 1.680 acoes (4 sementes); 1.0.97 = 0 em 840. Unicos caminhos que perdem peso de
  comanda enviada: sair do Balcao com peso nao salvo (corrigido 1.0.96) e Enter apressado com balanca oscilando (1.0.95).

## Histórico lado a lado e estado da conexão (28/10/2026)

    ENTRY=historico.ts OUT=historico.cjs node build.cjs && node historico.cjs     # 48 verificações, funções puras, relógio falso

- Cobre: dois dias sincronizados e um só no PC (R$ 1.000 contra R$ 800), nuvem sem resposta com cache, venda cancelada na nuvem, dia fora dos 30 dias, venda do Balcão que não saiu deste PC, pedidos do site fora da comparação, venda recusada, lista unificada sem duplicar, cache por dia e poda, e os limiares do aviso (1 minuto, 15 minutos, com fila).
- Esperado: TODOS OK. Rodar junto com fila.cjs (SEED=7 N=800) depois de qualquer mudança no sincronizador.

## Fase 4 do offline: cópia local, radar de rede, erro de envio (28/10/2026)

    ENTRY=fase4.ts OUT=fase4.cjs node build.cjs && node fase4.cjs      # 28 verificações

Teste em navegador real (login e abertura sem internet), manual:
1. `npx vite --port 5199` e uma página temporária que, COM internet, chama fetchStoreBySlug, fetchMenuForAdmin, fetchSettings e fetchAllPromotions, grava com gravarCopia e grava no localStorage uma sessão do Supabase com expires_at no passado (a chave é supabase.auth.storageKey).
2. Chrome headless com o mesmo --user-data-dir e `--host-resolver-rules="MAP *.supabase.co ~NOTFOUND"`, abrindo /acaidodudu/admin. Esperado: painel aberto com o cardápio da cópia, sem círculo girando.
3. Perfil novo (sem sessão) em /acaidodudu/login: a tela carrega.

## Login offline (28/10/2026)

    ENTRY=credencial.ts OUT=credencial.cjs node build.cjs && node credencial.cjs      # 30 verificações do módulo credencial-local.js

Teste de navegador do login: página temporária que define window.electron falso (storage e cacheLocal em localStorage, credencial com hash simples, Proxy que devolve Promise.resolve(null) para o resto e undefined para balcao), Chrome com --user-agent contendo Electron e --host-resolver-rules="MAP *.supabase.co ~NOTFOUND". Passos: (1) com internet, semear cópia, sessão vencida e credencial; (2) sem internet abrir /#/acaidodudu/admin e conferir que aparece a tela de login; (3) preencher e enviar o formulário por script (setter nativo do value + evento input) com a senha certa e a errada.
