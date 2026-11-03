// Balcão V2 OFFLINE: armazém + fila + sincronizador contra banco e disco FALSOS com falhas
// injetadas. Rodar:  ENTRY=fila.ts OUT=fila.cjs node build.cjs && node fila.cjs
// Invariantes: toda venda fechada chega ao banco EXATAMENTE uma vez; nada chega sem ter sido
// fechado; total = itens - desconto + taxa = soma dos pagamentos; reiniciar devolve o mesmo estado;
// o banco numera na ordem de fechamento.
const g: any = globalThis;
const disco: { texto: string | null; falhar: boolean; salvamentos: number } = { texto: null, falhar: false, salvamentos: 0 };
g.window = {
  addEventListener() {}, removeEventListener() {},
  electron: { balcao: {
    carregar: async () => disco.texto,
    salvar: async (t: string) => { if (disco.falhar) return { ok: false, erro: "disco cheio (simulado)" }; disco.texto = t; disco.salvamentos++; return { ok: true }; },
    diario: async () => true, log: async () => true, espacoLivre: async () => 1e12,
  } },
};
g.crypto ||= require("crypto").webcrypto;

import * as A from "@proj/offline/armazemBalcao";
import * as S from "@proj/offline/sincronizadorBalcao";

// ---------------- banco falso ----------------
type Modo = "ok" | "rede" | "perdida" | "lento" | "recusada" | "semColuna";
const banco = { linhas: new Map<string, any>(), inserts: 0, numero: 0, modo: "ok" as Modo, temColuna: true, chamadasUpsert: 0 };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const fakeSupabase = {
  from(tabela: string) {
    return {
      upsert: async (row: any) => {
        if (tabela !== "orders") return { error: null };
        banco.chamadasUpsert++;
        const m = banco.modo;
        if (m === "rede") return { error: { message: "TypeError: Failed to fetch", code: "" } };
        if (m === "recusada") return { error: { message: "null value violates not-null", code: "23502" } };
        if (!banco.temColuna && "pagamentos" in row) return { error: { message: "Could not find the 'pagamentos' column of 'orders' in the schema cache", code: "PGRST204" } };
        if (m === "lento") { await dormir(400); }
        if (!banco.linhas.has(row.id)) { banco.inserts++; banco.linhas.set(row.id, { ...row, daily_order_number: ++banco.numero }); }
        if (m === "perdida") return { error: { message: "TypeError: Failed to fetch (resposta perdida)", code: "" } };
        return { error: null };
      },
      select: () => ({ eq: (_c: string, id: string) => ({ maybeSingle: async () => {
        if (banco.modo === "rede") return { error: { message: "Failed to fetch", code: "" } };
        const l = banco.linhas.get(id); return { data: l ? { id: l.id, daily_order_number: l.daily_order_number } : null, error: null };
      } }) }),
    };
  },
};

let falhas = 0;
const confere = (nome: string, ok: boolean, extra = "") => { console.log(`${ok ? "ok  " : "FALHOU"} ${nome}${extra ? "  -> " + extra : ""}`); if (!ok) falhas++; };
const arred = (n: number) => Number(n.toFixed(2));
const item = (nome: string, preco: number, qtd = 1) => ({ id: Math.floor(Math.random() * 1e6), cartId: `c-${Math.random().toString(36).slice(2)}`, name: nome, price: preco, quantity: qtd, selectedAddons: [] });
const somaItens = (itens: any[]) => arred(itens.reduce((s, i) => s + (Number(i.price) || 0) * (Number(i.quantity) || 1), 0));

async function abrirComItens(n: number, itens: any[]) {
  return A.criarPedidoLocal({ table_number: n, comandaNumber: n, store_id: "s1", customerName: `Comanda ${n}`, orderType: "Balcão", origin: "BALCÃO", items: itens, total: somaItens(itens), status: "Novo" });
}
const totalLocal = (n: number) => arred(A.pedidosAbertosDaComanda(n).reduce((s, o) => s + (Number(o.total) || 0), 0));

async function reiniciar() { await A.__simularReinicioParaTeste(); await A.carregarArmazem(); }

(async () => {
  A.__reiniciarArmazemParaTeste(true);
  S.iniciarSincronizador({ supabase: fakeSupabase as any, storeId: "s1", intervaloMs: 1e9, timeoutMs: 150 });

  // ===== 1) Caminho feliz =====
  await abrirComItens(1, [item("Acai 500", 18), item("ADD 3", 3)]);
  let r: any = await A.fecharComandaLocal(1, 21, { method: "PIX", amountTendered: 21, discount: 0, tax: 0, finalTotal: 21 });
  confere("fecha comanda 1 (PIX 21)", r.ok === true);
  await S.processarFila();
  confere("venda 1 no banco, 1 vez", banco.linhas.size === 1 && banco.inserts === 1 && A.vendasNaFila().length === 0);

  // ===== 2) Rede fora: fecha 3 vendas, nada sobe; volta: sobem NA ORDEM =====
  banco.modo = "rede";
  const ordem: string[] = [];
  for (const [n, v] of [[2, 10], [3, 20], [4, 30]] as const) {
    await abrirComItens(n, [item("X", v)]);
    r = await A.fecharComandaLocal(n, v, { method: "Dinheiro", amountTendered: v, discount: 0, tax: 0, finalTotal: v });
    ordem.push(r.venda.id);
    S.dispararEnvio(); await dormir(5);
  }
  confere("sem internet: 3 na fila, nada novo no banco", A.vendasNaFila().length === 3 && banco.linhas.size === 1);
  banco.modo = "ok"; S.dispararEnvio(); await dormir(50); await S.processarFila();
  const nums = ordem.map(id => banco.linhas.get(id)?.daily_order_number);
  confere("internet voltou: as 3 subiram", A.vendasNaFila().length === 0 && ordem.every(id => banco.linhas.has(id)));
  confere("numeracao na ordem de fechamento", nums[0] < nums[1] && nums[1] < nums[2], JSON.stringify(nums));

  // ===== 3) Resposta perdida (banco gravou, resposta nao chegou): NAO duplica =====
  banco.modo = "perdida";
  await abrirComItens(5, [item("Y", 7)]);
  r = await A.fecharComandaLocal(5, 7, { method: "Cartão", amountTendered: 7, discount: 0, tax: 0, finalTotal: 7 });
  await S.processarFila();
  banco.modo = "ok"; S.dispararEnvio(); await dormir(50); await S.processarFila();
  confere("resposta perdida + reenvio = 1 linha so", [...banco.linhas.values()].filter(l => l.id === r.venda.id).length === 1 && A.vendasNaFila().length === 0);

  // ===== 4) Lento (timeout) + reenvio: NAO duplica =====
  banco.modo = "lento";
  await abrirComItens(6, [item("Z", 5)]);
  r = await A.fecharComandaLocal(6, 5, { method: "PIX", amountTendered: 5, discount: 0, tax: 0, finalTotal: 5 });
  await S.processarFila(); await dormir(500);
  banco.modo = "ok"; S.dispararEnvio(); await dormir(50); await S.processarFila();
  const ins6 = banco.inserts;
  confere("timeout + reenvio = 1 linha so", banco.linhas.has(r.venda.id) && A.vendasNaFila().length === 0, `inserts=${ins6}`);

  // ===== 5) Banco sem a coluna pagamentos: sobe sem ela =====
  banco.temColuna = false;
  await abrirComItens(7, [item("W", 9)]);
  r = await A.fecharComandaLocal(7, 9, { method: "PIX", amountTendered: 9, discount: 0, tax: 0, finalTotal: 9 });
  await S.processarFila();
  confere("sem coluna pagamentos: subiu mesmo assim", banco.linhas.has(r.venda.id) && !("pagamentos" in banco.linhas.get(r.venda.id)));
  banco.temColuna = true; S.__forcarRecheckColunaParaTeste(); // Ikarus rodou o SQL com o app aberto

  // ===== 6) Venda recusada: separa, NAO trava as outras =====
  banco.modo = "recusada";
  await abrirComItens(8, [item("R", 4)]);
  const recusada = (await A.fecharComandaLocal(8, 4, { method: "PIX", amountTendered: 4, discount: 0, tax: 0, finalTotal: 4 }) as any).venda.id;
  await S.processarFila();
  banco.modo = "ok";
  await abrirComItens(9, [item("Q", 6)]);
  const depois = (await A.fecharComandaLocal(9, 6, { method: "PIX", amountTendered: 6, discount: 0, tax: 0, finalTotal: 6 }) as any).venda.id;
  await S.processarFila();
  confere("recusada vai para problemas e a seguinte sobe", A.vendasComProblema().some(v => v.id === recusada) && banco.linhas.has(depois));

  // ===== 7) F8: parcial em dinheiro + PIX, fecha; Historico soma certo =====
  await abrirComItens(10, [item("Acai", 18), item("Acai", 18)]);
  await A.adicionarPagamentoLocal({ tableNumber: 10, amount: 18, paymentMethod: "Dinheiro" });
  await reiniciar(); // PC desligou no meio do F8
  confere("F8: pagamento parcial sobreviveu ao reinicio", A.saldoComandaLocal(10).paid === 18 && A.saldoComandaLocal(10).balance === 18);
  await A.adicionarPagamentoLocal({ tableNumber: 10, amount: 18, paymentMethod: "PIX" });
  const f8 = await A.fecharComandaPorSaldoLocal(10, false);
  await S.processarFila();
  const l10 = [...banco.linhas.values()].find(l => l.table_number === 10);
  confere("F8: venda Misto com Dinheiro 18 + PIX 18", f8.success && l10?.payment_method === "Misto" && l10?.pagamentos?.length === 2 && l10.total === 36, JSON.stringify(l10?.pagamentos));
  confere("F8: comanda 10 liberada (sem pagamento herdado)", A.saldoComandaLocal(10).payments.length === 0 && A.saldoComandaLocal(10).open_orders === 0);

  // ===== 8) F8 fechar sem quitar: recusa; force perdoa e registra =====
  await abrirComItens(11, [item("P", 10)]);
  await A.adicionarPagamentoLocal({ tableNumber: 11, amount: 9.5, paymentMethod: "Dinheiro" });
  const semForce = await A.fecharComandaPorSaldoLocal(11, false);
  const comForce = await A.fecharComandaPorSaldoLocal(11, true);
  await S.processarFila();
  const l11 = [...banco.linhas.values()].find(l => l.table_number === 11);
  confere("F8 sem quitar recusa; com force perdoa 0,50", !semForce.success && comForce.success && l11?.total === 9.5 && l11?.discount === 0.5);

  // ===== 9) Fechamento com total da tela diferente: BLOQUEIA =====
  await abrirComItens(12, [item("A", 13.57)]);
  const bloq: any = await A.fecharComandaLocal(12, 26.5, { method: "Dinheiro", amountTendered: 26.5, discount: 0, tax: 0, finalTotal: 26.5 });
  confere("tela 26,50 x comanda 13,57 bloqueia (caso #165)", bloq.ok === false && A.pedidosAbertosDaComanda(12).length === 1);
  await A.apagarPedidoLocal(A.pedidosAbertosDaComanda(12)[0].id!);

  // ===== 10) Disco falhando: avisa =====
  disco.falhar = true;
  await abrirComItens(13, [item("D", 1)]);
  confere("disco falhando: erroDeDisco aparece", !!A.erroDeDisco());
  disco.falhar = false;
  await A.apagarPedidoLocal(A.pedidosAbertosDaComanda(13)[0].id!);
  confere("disco voltou: erro some", !A.erroDeDisco());

  // ===== 11) FUZZ com invariantes =====
  let seed = Number(g.process?.env?.SEED || 7);
  const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  const fechadas = new Set<string>(A.vendasEnviadasRecentes().map(v => v.id).concat(A.vendasNaFila().map(v => v.id)));
  const N = Number(g.process?.env?.N || 600);
  for (let passo = 0; passo < N; passo++) {
    const n = 1 + Math.floor(rnd() * 20);
    const op = rnd();
    banco.modo = (["ok", "ok", "ok", "rede", "perdida", "lento"] as Modo[])[Math.floor(rnd() * 6)];
    if (op < 0.30) await abrirComItens(n, [item("F", Math.round(rnd() * 3000) / 100 + 1, 1 + Math.floor(rnd() * 3))]);
    else if (op < 0.38) { const ps = A.pedidosAbertosDaComanda(n); if (ps.length) await A.apagarPedidoLocal(ps[Math.floor(rnd() * ps.length)].id!); }
    else if (op < 0.48) { const s = A.saldoComandaLocal(n); if (s.open_orders && s.balance > 1) await A.adicionarPagamentoLocal({ tableNumber: n, amount: arred(s.balance / 2), paymentMethod: rnd() < 0.5 ? "Dinheiro" : "PIX" }); }
    else if (op < 0.62) {
      const t = totalLocal(n);
      if (t > 0 && A.saldoComandaLocal(n).paid === 0) {
        const desc = rnd() < 0.2 ? 1 : 0; const tax = rnd() < 0.2 ? 0.5 : 0;
        const rr: any = await A.fecharComandaLocal(n, t, { method: rnd() < 0.5 ? "Cartão" : "Dinheiro", amountTendered: t, discount: desc, tax, finalTotal: arred(t - desc + tax) });
        if (rr.ok) fechadas.add(rr.venda.id);
      }
    } else if (op < 0.70) {
      const s = A.saldoComandaLocal(n);
      if (s.open_orders && s.paid > 0) { const antes = new Set(A.vendasNaFila().map(v => v.id)); const rr = await A.fecharComandaPorSaldoLocal(n, true); if (rr.success) A.vendasNaFila().forEach(v => { if (!antes.has(v.id)) fechadas.add(v.id); }); }
    } else if (op < 0.78) { const antes = JSON.stringify(A.__retratoParaTeste()); await reiniciar(); if (JSON.stringify(A.__retratoParaTeste()) !== antes) { confere(`reinicio no passo ${passo} devolve o mesmo estado`, false); } }
    else { S.dispararEnvio(); await dormir(rnd() < 0.3 ? 30 : 2); }
  }
  // Fim: internet boa, esvazia a fila
  banco.modo = "ok";
  for (let i = 0; i < 20 && A.vendasNaFila().length > 0; i++) { S.dispararEnvio(); await dormir(30); await S.processarFila(); }
  const problemas = new Set(A.vendasComProblema().map(v => v.id));
  const noBanco = [...banco.linhas.values()];
  const idsBanco = new Set(noBanco.map(l => l.id));
  const faltando = [...fechadas].filter(id => !idsBanco.has(id) && !problemas.has(id));
  const fantasmas = noBanco.filter(l => !fechadas.has(l.id));
  confere(`FUZZ ${N} passos: toda venda fechada chegou (${fechadas.size} vendas)`, faltando.length === 0, faltando.length ? `faltando ${faltando.length}` : "");
  confere("FUZZ: nenhuma venda duplicada no banco", banco.inserts === banco.linhas.size, `inserts=${banco.inserts} linhas=${banco.linhas.size}`);
  confere("FUZZ: nada no banco sem ter sido fechado", fantasmas.length === 0);
  const ruins = noBanco.filter(l => {
    const itens = somaItens(l.items || []);
    const pag = arred((l.pagamentos || [{ valor: l.total }]).reduce((s: number, p: any) => s + p.valor, 0));
    return Math.abs(arred(itens - (l.discount || 0) + (l.tax || 0)) - l.total) > 0.011 || Math.abs(pag - l.total) > 0.011;
  });
  confere("FUZZ: total = itens - desconto + taxa = pagamentos, em todas", ruins.length === 0, ruins.slice(0, 2).map(l => `${l.total}`).join(","));
  confere("FUZZ: fila vazia no fim", A.vendasNaFila().length === 0);

  console.log(`\nFALHAS: ${falhas}`);
  g.process.exit(falhas ? 1 : 0);
})();
