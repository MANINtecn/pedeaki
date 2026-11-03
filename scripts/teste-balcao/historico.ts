// Histórico lado a lado + estado da conexão (28/10/2026). Funções puras, sem rede.
//   ENTRY=historico.ts OUT=historico.cjs node build.cjs && node historico.cjs
const g: any = globalThis;
g.window = { addEventListener() {}, removeEventListener() {}, electron: { balcao: {} } };
g.crypto ||= require("crypto").webcrypto;

import { compararPorDia, montarListaUnificada, resumirNuvem, lerCacheNuvem, gravarCacheNuvem, diaLocal } from "@proj/offline/historicoDuasCamadas";
import { lerEstadoConexao, registrarFalha, registrarSucesso, __zerarConexaoParaTeste, LIMIARES } from "@proj/offline/estadoConexao";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

const AGORA = new Date(2026, 9, 28, 12, 0, 0).getTime();
const dia = (dd: number, hora = 12) => new Date(2026, 9, dd, hora, 0, 0).toISOString();
const ymd = (dd: number) => `2026-10-${String(dd).padStart(2, "0")}`;

let seq = 0;
const venda = (dd: number, total: number, id = `v${++seq}`): any => ({
  id, storeId: "L", comanda: 1, nome: "", itens: [], pagamentos: [{ forma: "Dinheiro", valor: total }],
  desconto: 0, taxa: 0, total, abertaEm: dia(dd), fechadaEm: dia(dd), maquina: "m", tentativas: 0,
});
const pedido = (v: any, origin = "BALCÃO"): any => ({ id: v.id, timestamp: v.fechadaEm, total: v.total, origin, status: "Entregue", items: [] });
const livro = (fila: any[] = [], enviadas: any[] = [], problemas: any[] = []) => ({ fila, enviadas, problemas });
const args = (o: any) => ({ cache: null, inicio: ymd(24), fim: ymd(26), agora: AGORA, diasGuardando: 30, ...o });

// ---- S1: tudo sincronizado (o exemplo do Ikarus, "internet ativa e sincronizada")
{
  const a = [venda(24, 400), venda(25, 400), venda(26, 200)];
  const c = compararPorDia(args({ livro: livro([], a), banco: a.map(v => pedido(v)) }));
  igual("S1 3 dias, mesmo valor dos dois lados", [c.totais.pcValor, c.totais.nuvemValor, c.totais.uniaoValor], [1000, 1000, 1000]);
  ok("S1 todos os dias sincronizados", c.linhas.every(l => l.situacao === "sincronizado"));
  igual("S1 nada só no PC", c.totais.soNoPcQtd, 0);
}

// ---- S2: o exemplo do Ikarus: 2 dias com internet (R$ 800) e 1 dia sem (R$ 200 só no PC)
{
  const d1 = venda(24, 400), d2 = venda(25, 400), d3 = venda(26, 200), d3b = venda(26, 0.01);
  const c = compararPorDia(args({ livro: livro([d3], [d1, d2]), banco: [pedido(d1), pedido(d2)] }));
  igual("S2 PC 1000 / nuvem 800 / união 1000", [c.totais.pcValor, c.totais.nuvemValor, c.totais.uniaoValor], [1000, 800, 1000].map((x, i) => i === 1 ? 800 : x));
  igual("S2 situação por dia", c.linhas.map(l => l.situacao), ["sincronizado", "sincronizado", "aguardando"]);
  igual("S2 200 só neste PC", [c.totais.soNoPcQtd, c.totais.soNoPcValor], [1, 200]);
  void d3b;
}

// ---- S3: nuvem sem resposta (banco = null): vale o PC; "último valor conhecido" vem do cache
{
  const d1 = venda(24, 400), d2 = venda(25, 400), d3 = venda(26, 200);
  const cache: any = { [ymd(24)]: { bq: 1, bv: 400, oq: 2, ov: 90, em: AGORA - 3600e3 }, [ymd(25)]: { bq: 1, bv: 400, oq: 0, ov: 0, em: AGORA - 3600e3 } };
  const c = compararPorDia(args({ livro: livro([d3], [d1, d2]), banco: null, cache }));
  ok("S3 nuvem indisponível", c.bancoDisponivel === false);
  igual("S3 união = o que o PC tem", c.totais.uniaoValor, 1000);
  igual("S3 nuvem mostra o último valor conhecido (800)", c.totais.nuvemValor, 800);
  ok("S3 linhas vindas do cache marcadas", c.linhas.filter(l => l.nuvemDeCache).length === 2);
  igual("S3 site vem do cache", c.site, { qtd: 2, valor: 90, deCache: true });
  igual("S3 dia com fila = aguardando, os outros = sem conexão", c.linhas.map(l => l.situacao), ["sem_conexao", "sem_conexao", "aguardando"]);
  const semCache = compararPorDia(args({ livro: livro([d3], [d1, d2]), banco: null, cache: null }));
  igual("S3 sem cache a coluna da nuvem fica vazia, nunca zero falso", semCache.totais.nuvemValor, null);
  igual("S3 sem cache a união continua certa", semCache.totais.uniaoValor, 1000);
}

// ---- S4: venda enviada que sumiu da nuvem foi cancelada: sai da conta do PC (colunas continuam iguais)
{
  const a = venda(24, 100), b = venda(24, 50);
  const c = compararPorDia(args({ livro: livro([], [a, b]), banco: [pedido(a)] }));
  igual("S4 PC não conta a cancelada", [c.totais.pcValor, c.totais.nuvemValor], [100, 100]);
  igual("S4 anota 1 cancelada", c.canceladasNaNuvem, 1);
  ok("S4 dia continua sincronizado", c.linhas[0].situacao === "sincronizado");
}

// ---- S5: dia fora dos 30 dias: só a nuvem tem
{
  const antiga = { id: "x1", timestamp: new Date(2026, 8, 1, 12).toISOString(), total: 70, origin: "BALCÃO" } as any;
  const c = compararPorDia({ livro: livro(), banco: [antiga], cache: null, inicio: "2026-09-01", fim: "2026-09-01", agora: AGORA, diasGuardando: 30 });
  igual("S5 só na nuvem, PC indisponível", [c.linhas[0].situacao, c.linhas[0].pcDisponivel, c.linhas[0].nuvemValor], ["so_nuvem", false, 70]);
  igual("S5 total do PC não soma dia sem dados", c.totais.pcValor, 0);
}

// ---- S6: venda de Balcão na nuvem que não saiu deste PC (dentro dos 30 dias)
{
  const mine = venda(24, 30), other = venda(24, 45);
  const c = compararPorDia(args({ livro: livro([], [mine]), banco: [pedido(mine), pedido(other)] }));
  igual("S6 diferença na nuvem", [c.linhas[0].situacao, c.linhas[0].soNaNuvemQtd, c.linhas[0].soNaNuvemValor], ["diferenca", 1, 45]);
  igual("S6 união = nuvem (a do outro caminho conta)", c.totais.uniaoValor, 75);
}

// ---- S7: pedidos do site/robô não entram na comparação do Balcão
{
  const a = venda(24, 100);
  const site = { id: "w1", timestamp: dia(24), total: 33, origin: "WEB", status: "Entregue" } as any;
  const c = compararPorDia(args({ livro: livro([], [a]), banco: [pedido(a), site] }));
  igual("S7 colunas só com Balcão", [c.totais.pcValor, c.totais.nuvemValor], [100, 100]);
  igual("S7 site em linha separada", c.site, { qtd: 1, valor: 33, deCache: false });
}

// ---- S8: venda que acabou de subir (ainda na fila e já na nuvem) não conta como "só no PC" nem duplica
{
  const a = venda(24, 100);
  const c = compararPorDia(args({ livro: livro([a], []), banco: [pedido(a)] }));
  igual("S8 sincronizado, 0 só no PC", [c.linhas[0].situacao, c.totais.soNoPcQtd, c.totais.pcValor, c.totais.nuvemValor], ["sincronizado", 0, 100, 100]);
  const lista = montarListaUnificada({ banco: [pedido(a)], livro: livro([a]), inicio: ymd(24), fim: ymd(26) });
  igual("S8 lista sem duplicar", lista.map(o => o.id), [a.id]);
}

// ---- S9: venda recusada pelo banco (problema) conta como só no PC e é avisada
{
  const r = venda(25, 60);
  const c = compararPorDia(args({ livro: livro([], [], [r]), banco: [] }));
  igual("S9 recusada conta como só no PC", [c.totais.soNoPcQtd, c.recusadas], [1, { qtd: 1, valor: 60 }]);
}

// ---- S10: lista unificada
{
  const sent = venda(24, 10), pend = venda(25, 20), so = venda(26, 5);
  const nuvem = montarListaUnificada({ banco: [pedido(sent)], livro: livro([pend], [sent]), inicio: ymd(24), fim: ymd(26) });
  igual("S10 online: nuvem + pendente, sem a enviada duplicada", nuvem.map(o => o.id).sort(), [pend.id, sent.id].sort());
  ok("S10 pendente marcada", nuvem.find(o => o.id === pend.id)!.pendenteEnvio === true);
  const off = montarListaUnificada({ banco: null, livro: livro([pend], [sent, so]), inicio: ymd(24), fim: ymd(26) });
  igual("S10 offline: o livro todo, nunca vazio", off.map(o => o.id).sort(), [pend.id, sent.id, so.id].sort());
  ok("S10 offline: enviada vem marcada como do livro e NÃO como pendente", off.filter(o => o.viaLivroDoPc).length === 2 && off.filter(o => o.pendenteEnvio).length === 1);
  const fora = montarListaUnificada({ banco: null, livro: livro([pend]), inicio: ymd(1), fim: ymd(2) });
  igual("S10 período sem vendas = lista vazia", fora.length, 0);
}

// ---- S11: cache do "último valor conhecido"
{
  const store = new Map<string, string>();
  const st = { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => { store.set(k, v); } };
  const a = venda(24, 100), b = venda(25, 50);
  gravarCacheNuvem("L", resumirNuvem([pedido(a), pedido(b)], AGORA), ymd(24), ymd(26), AGORA, st);
  const c1 = lerCacheNuvem("L", st)!;
  igual("S11 grava por dia", [c1[ymd(24)].bv, c1[ymd(25)].bv, c1[ymd(26)]], [100, 50, undefined]);
  // nova consulta do mesmo período, agora a nuvem não tem mais a venda b (cancelada): o dia vazio SOBRESCREVE
  gravarCacheNuvem("L", resumirNuvem([pedido(a)], AGORA + 1), ymd(24), ymd(26), AGORA + 1, st);
  const c2 = lerCacheNuvem("L", st)!;
  igual("S11 dia que ficou vazio não deixa valor velho", c2[ymd(25)], undefined);
  const velho = { "2020-01-01": { bq: 1, bv: 9, oq: 0, ov: 0, em: 1 } } as any;
  store.set("historico_nuvem_v1:L", JSON.stringify(velho));
  gravarCacheNuvem("L", resumirNuvem([pedido(a)], AGORA), ymd(24), ymd(24), AGORA, st);
  ok("S11 poda dias com mais de 90 dias", lerCacheNuvem("L", st)!["2020-01-01"] === undefined);
  ok("S11 sem storage não quebra", (() => { try { gravarCacheNuvem("L", {}, ymd(24), ymd(24), AGORA, null); return lerCacheNuvem("L", null) === null; } catch (_) { return false; } })());
}

// ---- S12: estado da conexão (relógio falso)
{
  __zerarConexaoParaTeste();
  const T0 = 1_000_000_000_000;
  const fila = (k: number) => Array.from({ length: k }, (_, i) => ({ total: 10, fechadaEm: new Date(T0 - i * 1000).toISOString() }));
  igual("S12 nunca falhou, fila vazia: ok", lerEstadoConexao([], T0).nivel, "ok");
  igual("S12 com fila e nuvem respondendo: enviando", lerEstadoConexao(fila(3), T0).nivel, "enviando");
  registrarFalha("TypeError: Failed to fetch", T0);
  igual("S12 falhou há 30 s: ainda não alerta (sem fila)", lerEstadoConexao([], T0 + 30_000).nivel, "ok");
  igual("S12 falhou há 30 s com fila: enviando", lerEstadoConexao(fila(2), T0 + 30_000).nivel, "enviando");
  igual("S12 falhou há 1 min sem fila: atenção (amarelo)", lerEstadoConexao([], T0 + LIMIARES.atencaoMs).nivel, "atencao");
  igual("S12 falhou há 1 min COM fila: crítico (vermelho)", lerEstadoConexao(fila(1), T0 + LIMIARES.atencaoMs).nivel, "critico");
  igual("S12 falhou há 15 min sem fila: crítico", lerEstadoConexao([], T0 + LIMIARES.criticoMs).nivel, "critico");
  const e = lerEstadoConexao(fila(3), T0 + 120_000);
  igual("S12 conta e soma a fila", [e.naFila, e.valorNaFila, e.duracaoMs], [3, 30, 120_000]);
  ok("S12 mais antiga da fila", e.maisAntigaEm === new Date(T0 - 2000).toISOString());
  registrarFalha("outra falha", T0 + 90_000);
  igual("S12 nova falha não reinicia o relógio da queda", lerEstadoConexao([], T0 + 120_000).desde, T0);
  registrarSucesso(T0 + 130_000);
  igual("S12 voltou: some o alerta", lerEstadoConexao([], T0 + 131_000).nivel, "ok");
  igual("S12 voltou com fila: enviando", lerEstadoConexao(fila(2), T0 + 131_000).nivel, "enviando");
}

// ---- S13: recorte de dia usa o fuso do computador
igual("S13 diaLocal", diaLocal(new Date(2026, 9, 24, 23, 59, 59)), "2026-10-24");

console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
process.exit(falhas ? 1 : 0);
