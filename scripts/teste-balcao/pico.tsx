// BATERIA DE PICO -- Balcão V2 OFFLINE com o CounterTab REAL (15/10/2026).
// Uma "atendente" aleatória trabalha em várias comandas ao mesmo tempo, como no pico:
// abre comanda (número+Enter, C, setas), troca de comanda no meio (rascunho), volta em comanda já
// enviada, digita códigos, lança pesos, apaga o último item (Delete), soma (+), envia (Enter, às
// vezes vários seguidos), fecha a tela (X), fecha a conta (F7), divide a conta (F8), e o PC
// "reinicia" no meio. Tudo com pausas aleatórias de 0 a 700 ms.
//
// JUIZ: um modelo próprio do que FOI LANÇADO em cada comanda.
//   - depois de cada ação, com a comanda aberta: a tela tem que mostrar EXATAMENTE o modelo;
//   - no F7/F8: a venda tem que ser EXATAMENTE o modelo (nada a menos, nada a mais);
//   - o banco não pode ser chamado nenhuma vez; F7 tem que fechar rápido.
//
//   ENTRY=pico.tsx OUT=pico.cjs node build.cjs && SESSOES=20 PASSOS=60 SEED=1 NODE_PATH=$PWD/node_modules node pico.cjs
import "./prelude";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import * as A from "@novo/offline/armazemBalcao";
import { definirContextoBalcao } from "@novo/services/comandaBackend";
import { banco, criarNoBanco, updateOrder as atualizarNoBanco, fetchAllOpenOrdersForTable as abertosDaMesaNoBanco } from "./stub-supabase";
import { planejarFechamentoMesa } from "@novo/utils/fechamentoMesa";

const g: any = globalThis; const w: any = g.window;
const env: any = g.process?.env || {};
// MODO=online: a V2 de reserva (= produção com a 1.0.91): comandas no banco falso, com latência variável.
const MODO: "offline" | "online" = env.MODO === "online" ? "online" : "offline";
const disco: { texto: string | null } = { texto: null };
if (MODO === "offline") w.electron = { balcao: {
  carregar: async () => disco.texto,
  salvar: async (t: string) => { disco.texto = t; return { ok: true }; },
  diario: async () => true, log: async () => true, espacoLivre: async () => 1e12,
} };
const clone = (x: any) => JSON.parse(JSON.stringify(x));
const abertosNoBanco = () => clone(banco.orders.filter((o: any) => !["Entregue", "Cancelado"].includes(o.status)));
const _err = console.error; console.error = (...a: any[]) => { const s = String(a[0]); if (s.includes("not wrapped in act") || s.includes("[Balcao]")) return; _err(...a); };
const _log = console.log; console.log = (...a: any[]) => { if (String(a[0]).startsWith("[Balcao]")) return; if (env.VERBOSO) _log(...a); };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));

const categories: any[] = [{ id: 1, name: "Milk" }, { id: 3, name: "Acai" }];
const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [
  { ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] },
  { ...base, id: 333, name: "ADD 3", price: 3, categoryId: 3, codigo: 333, allowedAddons: [] },
  { ...base, id: 222, name: "AGUA", price: 4, categoryId: 1, codigo: 222, allowedAddons: [] },
];
const PRECO: Record<string, number> = { "MILK-SHAKE": 15, "ADD 3": 3, "AGUA": 4 };
const settings: any = { balcaoV2: true, isScaleEnabled: false, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let enviarRef: any = null; let setSinal: any = null; let comandaAtiva: number | null = null;
let ordersRefOnline: any[] = []; let setAtivosOnline: any = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [sinal, _s] = useState(0); setSinal = _s;
  const [ativos, setAtivos] = useState<any[]>(abertosNoBanco()); setAtivosOnline = setAtivos; ordersRefOnline = ativos;
  useEffect(() => A.assinarArmazem(() => setVer(v => v + 1)), []);
  const ref = useRef<any>(null); enviarRef = ref;
  const onOrderComplete = async (order: any) => {
    if (MODO === "offline") {
      if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order);
      else await A.criarPedidoLocal(order);
      return;
    }
    // = handleCounterOrderComplete online: grava no banco e recarrega a lista (recarregarSoPedidos)
    if (order.id) await atualizarNoBanco(order.id, order); else await criarNoBanco(order);
    await dormir(banco.latencia);
    setAtivos(abertosNoBanco());
  };
  return <CounterTab categories={categories} menuItems={menuItems} addons={[]} settings={settings} storeId="s1"
    onOrderComplete={onOrderComplete} activeOrders={MODO === "offline" ? A.pedidosAbertosLocais() : ativos} enviarComandaAtivaRef={ref}
    fecharComandaSignal={sinal} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};

// ---------------- teclado / tela ----------------
const press = (key: string, alvo: any = w) => alvo.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms: number, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
type Conteudo = Map<string, number>;
const telaDaComanda = (): Conteudo => {
  const m: Conteudo = new Map();
  document.querySelectorAll('button[title="Remover item"]').forEach(b => {
    const linha = b.parentElement!;
    const nome = (linha.querySelector("span")?.childNodes[0]?.textContent || "").trim();
    const qtd = Number(linha.querySelector("span.px-1\\.5")?.textContent || "1");
    m.set(nome, (m.get(nome) || 0) + qtd);
  });
  return m;
};
const ultimaLinha = (): { nome: string; qtd: number } | null => {
  const bs = document.querySelectorAll('button[title="Remover item"]');
  if (!bs.length) return null;
  const linha = bs[bs.length - 1].parentElement!;
  return { nome: (linha.querySelector("span")?.childNodes[0]?.textContent || "").trim(), qtd: Number(linha.querySelector("span.px-1\\.5")?.textContent || "1") };
};
const igual = (a: Conteudo, b: Conteudo) => { const ks = new Set([...a.keys(), ...b.keys()]); for (const k of ks) if ((a.get(k) || 0) !== (b.get(k) || 0)) return false; return true; };
const txt = (m: Conteudo) => JSON.stringify([...m.entries()].filter(([, q]) => q).sort());
const doVenda = (itens: any[]): Conteudo => { const m: Conteudo = new Map(); itens.forEach(i => m.set(i.name, (m.get(i.name) || 0) + (Number(i.quantity) || 1))); return m; };
// Cada peso vale kg x 64 ARREDONDADO no item (o app arredonda por item, não no total).
const valorDe = (m: Conteudo) => Number([...m.entries()].reduce((s, [n, q]) => s + q * (PRECO[n] ?? Number((Number((n.match(/\(([\d,]+) kg\)/)?.[1] || "0").replace(",", ".")) * 64).toFixed(2))), 0).toFixed(2));

// ---------------- sessão ----------------
let seed = Number(env.SEED || 1);
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const escolhe = <T,>(xs: T[]) => xs[Math.floor(rnd() * xs.length)];
const pausa = () => { const r = rnd(); return r < 0.4 ? 5 : r < 0.75 ? 80 : r < 0.92 ? 300 : 700; };

let problemas: string[] = [];
let estat = { acoes: 0, vendas: 0, f8: 0, pesos: 0, codigos: 0, trocas: 0, reinicios: 0, enters: 0, apagados: 0, recusasSemComanda: 0, f7ms: [] as number[], bloqueios: 0, f7SemAbrir: 0 };

async function sessao(numero: number, passos: number) {
  A.__reiniciarArmazemParaTeste(MODO === "offline"); definirContextoBalcao(true); disco.texto = null;
  banco.orders = []; banco.seq = 0; banco.latencia = MODO === "offline" ? 3000 : 150; w.localStorage.clear(); comandaAtiva = null;
  const modelo = new Map<number, Conteudo>();
  const de = (n: number) => { if (!modelo.has(n)) modelo.set(n, new Map()); return modelo.get(n)!; };
  let root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(50); });
  const historico: string[] = [];
  const falha = (msg: string) => { problemas.push(`sessao ${numero} (SEED ${env.SEED || 1}): ${msg}\n      ultimas acoes: ${historico.slice(-8).join(" > ")}`); };

  const salvoDaComanda = (n: number): Conteudo => {
    const ps = MODO === "offline" ? A.pedidosAbertosDaComanda(n) : abertosNoBanco().filter((o: any) => Number(o.table_number) === n);
    return doVenda(ps.flatMap((o: any) => o.items || []));
  };
  const apertarX = async (ms: number) => {
    const n = comandaAtiva;
    if (n != null && telaDaComanda().size === 0) { const salvo = salvoDaComanda(n); if (salvo.size) modelo.set(n, salvo); }
    await passo(ms, () => press("x"));
  };
  const conferirTela = async (onde: string) => {
    if (comandaAtiva == null) return;
    await passo(40);
    if (comandaAtiva == null) return;
    const t = telaDaComanda(), m = de(comandaAtiva);
    if (!igual(t, m)) falha(`${onde}: comanda ${comandaAtiva} na TELA ${txt(t)} x LANCADO ${txt(m)}`);
  };

  const fecharConta = async (comF8: boolean) => {
    if (comandaAtiva == null) return;
    const n = comandaAtiva;
    const t0 = Date.now();
    const ok = enviarRef.current ? await enviarRef.current() : true;
    if (!ok) { falha(`F7 da comanda ${n} recusou enviar (ok=false) com a comanda aberta`); return; }
    if (MODO === "online") {
      // = AdminPage F7 online: monta a conta pela lista LOCAL (ordersRef, 5 tentativas de 100 ms)...
      const esperadoOn = de(n);
      let virt: any[] = [];
      for (let k = 0; k < 6; k++) { virt = ordersRefOnline.filter((o: any) => Number(o.table_number) === n); if (virt.length) break; await dormir(100); }
      if (!virt.length) { if ([...esperadoOn.values()].some(q => q > 0)) estat.f7SemAbrir++; return; }
      const totalTela = Number(virt.reduce((s: number, o: any) => s + (Number(o.total) || 0), 0).toFixed(2));
      // ...e o checkout confere com o BANCO (trava da 1.0.91). Não bateu = nada cobrado, comanda segue aberta.
      const subs = await abertosDaMesaNoBanco("s1", n);
      const plano = planejarFechamentoMesa(subs.map((o: any) => ({ id: o.id, total: Number(o.total) || 0 })), totalTela, { discount: 0, tax: 0, finalTotal: totalTela });
      if (!plano.ok) { estat.bloqueios++; return; }
      for (const p of plano.partes) await atualizarNoBanco(p.id, { status: "Entregue", total: p.total });
      estat.f7ms.push(Date.now() - t0);
      const vendidoOn = doVenda(subs.flatMap((o: any) => o.items || []));
      if (!igual(vendidoOn, esperadoOn)) falha(`F7 comanda ${n}: COBRADO ${txt(vendidoOn)} x LANCADO ${txt(esperadoOn)}`);
      if (Math.abs(totalTela - valorDe(esperadoOn)) > 0.011) falha(`F7 comanda ${n}: total R$ ${totalTela} x esperado R$ ${valorDe(esperadoOn)}`);
      modelo.set(n, new Map());
      estat.vendas++;
      await act(async () => { setAtivosOnline(abertosNoBanco()); setSinal((v: number) => v + 1); await dormir(40); });
      return;
    }
    const ps = A.pedidosAbertosDaComanda(n);
    const esperado = de(n);
    if (!ps.length) { if ([...esperado.values()].some(q => q > 0)) falha(`F7 comanda ${n}: nada salvo, mas foi lancado ${txt(esperado)}`); return; }
    const total = Number(ps.reduce((s, o) => s + (Number(o.total) || 0), 0).toFixed(2));
    const antes = A.vendasNaFila().length;
    if (comF8) {
      const metade = Number((total / 2).toFixed(2));
      await A.adicionarPagamentoLocal({ tableNumber: n, amount: metade, paymentMethod: "Dinheiro" });
      await A.adicionarPagamentoLocal({ tableNumber: n, amount: Number((total - metade).toFixed(2)), paymentMethod: "PIX" });
      const r = await A.fecharComandaPorSaldoLocal(n, false);
      if (!r.success) { falha(`F8 comanda ${n} nao fechou: ${(r as any).error}`); return; }
      estat.f8++;
    } else {
      const r: any = await A.fecharComandaLocal(n, total, { method: escolhe(["Dinheiro", "PIX", "Cartão"]), amountTendered: total, discount: 0, tax: 0, finalTotal: total });
      if (!r.ok) { falha(`F7 comanda ${n} bloqueado: tela ${r.totalTela} x local ${r.totalLocal}`); return; }
    }
    estat.f7ms.push(Date.now() - t0);
    const venda = A.vendasNaFila()[antes];
    if (!venda) { falha(`F7 comanda ${n}: venda nao entrou na fila`); return; }
    const vendido = doVenda(venda.itens);
    if (!igual(vendido, esperado)) falha(`F7 comanda ${n}: VENDA ${txt(vendido)} x LANCADO ${txt(esperado)}`);
    if (Math.abs(venda.total - valorDe(esperado)) > 0.011) falha(`F7 comanda ${n}: total R$ ${venda.total} x esperado R$ ${valorDe(esperado)}`);
    const pag = Number(venda.pagamentos.reduce((s, p) => s + p.valor, 0).toFixed(2));
    if (Math.abs(pag - venda.total) > 0.011) falha(`F7 comanda ${n}: pagamentos R$ ${pag} x total R$ ${venda.total}`);
    modelo.set(n, new Map());
    estat.vendas++;
    await act(async () => { setSinal((v: number) => v + 1); await dormir(40); });
  };

  const TRACE = Number(env.TRACE || 0) === numero;
  const curto = (x: string) => x.split("Açaí/Sorvete por Quilo ").join("P");
  const avisoNaTela = () => {
    const t = (document.body.textContent || "").replace(/\s+/g, " ");
    const m = t.match(/(Mesa \d+[^.]{0,60}|Comanda \d+ · [^.]{0,40}|ENTER[^.]{0,60}|Enviar[^.]{0,60}|Confirm[^.]{0,60}|Cancelado[^.]{0,40}|Nenhuma comanda[^.]{0,30}|ocupadas|Aguarde[^.]{0,40}|Selecionar Mesa[^.]{0,40}|Lançar na mesa[^.]{0,40})/g);
    return JSON.stringify((m || []).slice(0, 3));
  };
  const rastro = (rot: string) => { if (!TRACE) return; const loc: any = {}; (MODO === "offline" ? A.pedidosAbertosLocais() : abertosNoBanco()).forEach((o: any) => { (loc[o.table_number] ||= []).push("{" + String(o.id).slice(-3) + " R$" + o.total + ": " + (o.items || []).map((it: any) => curto(it.name) + "x" + it.quantity).join(",") + "}"); }); let ras: any = {}; try { ras = JSON.parse(w.localStorage.getItem("acaiDoDudu:rascunhosComandaV2:s1") || "{}"); } catch (_) {} const rr: any = {}; Object.keys(ras).forEach(k => { rr[k] = (ras[k].cart || []).map((it: any) => curto(it.name) + "x" + it.quantity); }); g.process.stdout.write("  [" + rot + "] ativa=" + comandaAtiva + " tela=" + curto(txt(telaDaComanda())) + " disco=" + JSON.stringify(loc) + " rascunhos=" + JSON.stringify(rr) + " AVISO=" + avisoNaTela() + String.fromCharCode(10)); };
  for (let i = 0; i < passos; i++) {
    estat.acoes++;
    if (TRACE && i > 0) rastro(historico[historico.length - 1] || "");
    if (MODO === "online") banco.latencia = escolhe([30, 150, 600]); // internet boa, normal e ruim
    const r = rnd();
    const aberta = comandaAtiva != null;
    try {
      if (!aberta || r < 0.10) {
        // abrir/trocar de comanda: número+Enter (de dentro ou de fora), C, ou setas
        // (mesmo caso conhecido do X: apagou tudo e trocou sem Enter -> os itens salvos voltam)
        if (aberta && telaDaComanda().size === 0) { const salvo = salvoDaComanda(comandaAtiva!); if (salvo.size) modelo.set(comandaAtiva!, salvo); }
        const modo = rnd();
        if (modo < 0.65) { const n = 1 + Math.floor(rnd() * 6); historico.push(`abre ${n}`); for (const c of String(n)) await passo(8, () => press(c)); await passo(pausa() + 250, () => press("Enter")); }
        else if (modo < 0.85) { historico.push("C"); await passo(pausa() + 250, () => press("c")); }
        else { if (aberta) { historico.push("X"); await apertarX(60); } historico.push("seta"); await passo(pausa() + 250, () => press(rnd() < 0.5 ? "ArrowDown" : "ArrowUp")); }
        estat.trocas++;
        await conferirTela("depois de abrir/trocar");
      } else if (r < 0.40) {
        const cod = escolhe(["103", "333", "222"]); const nome = menuItems.find(p => String(p.codigo) === cod).name;
        const n = comandaAtiva!;
        historico.push(`cod ${cod}@${n}`);
        for (const c of cod) await passo(5, () => press(c));
        await passo(pausa());
        if (comandaAtiva === n) { const m = de(n); m.set(nome, (m.get(nome) || 0) + 1); estat.codigos++; }
        await conferirTela(`depois do codigo ${cod}`);
      } else if (r < 0.58) {
        const kg = (0.1 + Math.floor(rnd() * 500) / 1000).toFixed(3);
        const n = comandaAtiva!;
        historico.push(`peso ${kg}@${n}`);
        await passo(60, () => press("b"));
        const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
        if (input) {
          await act(async () => { Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, "value")!.set!.call(input, kg); input.dispatchEvent(new w.Event("input", { bubbles: true })); await dormir(15); });
          const abertaAntes = comandaAtiva;
          await act(async () => { press("Enter", input); await dormir(30); });
          const nome = `Açaí/Sorvete por Quilo (${kg.replace(".", ",")} kg)`;
          if (abertaAntes === n) { const m = de(n); m.set(nome, (m.get(nome) || 0) + 1); estat.pesos++; } else estat.recusasSemComanda++;
        } else historico.push("(modal do peso nao abriu)");
        await passo(pausa());
        await conferirTela(`depois do peso ${kg}`);
      } else if (r < 0.64) {
        const u = ultimaLinha();
        if (u) {
          historico.push(`Delete(${u.nome})`);
          await passo(pausa() + 20, () => press("Delete"));
          const m = de(comandaAtiva!); m.set(u.nome, (m.get(u.nome) || 0) - u.qtd); estat.apagados++;
          await conferirTela("depois do Delete");
        }
      } else if (r < 0.68) {
        const u = ultimaLinha();
        if (u) { historico.push(`+(${u.nome})`); await passo(pausa() + 20, () => press("+")); const m = de(comandaAtiva!); m.set(u.nome, (m.get(u.nome) || 0) + 1); await conferirTela("depois do +"); }
      } else if (r < 0.84) {
        const vezes = rnd() < 0.25 ? 2 + Math.floor(rnd() * 4) : 1;
        historico.push(`Enter x${vezes}`);
        await dormir(rnd() < 0.5 ? 550 : 50);
        for (let k = 0; k < vezes; k++) await passo(rnd() < 0.5 ? 15 : 120, () => press("Enter"));
        estat.enters += vezes;
        await passo(250);
        await conferirTela("depois do Enter");
      } else if (r < 0.88) {
        historico.push("X"); await apertarX(pausa() + 50);
      } else if (r < 0.97) {
        historico.push(`F7@${comandaAtiva}`); await dormir(rnd() < 0.5 ? 0 : 200);
        const querF8 = rnd() < 0.2;
        await fecharConta(MODO === "offline" && querF8); // F8 online depende de RPCs que o banco falso nao tem
      } else if (rnd() < 0.6) {
        // SAI DA ABA com a comanda ABERTA, sem X (vai em Pedidos/F5 e volta) -- 19/10/2026, aba.tsx:
        // era o que fazia o peso "sumir sozinho" (comanda 5 de 18/10). Nada lançado pode se perder.
        historico.push(`ABA(com ${comandaAtiva ?? "-"} aberta)`);
        if (comandaAtiva != null && telaDaComanda().size === 0) { const salvo = salvoDaComanda(comandaAtiva); if (salvo.size) modelo.set(comandaAtiva, salvo); }
        await act(async () => { root.unmount(); });
        comandaAtiva = null;
        await dormir(rnd() < 0.5 ? 50 : 400);
        root = createRoot(document.getElementById("root")!);
        await act(async () => { root.render(<Parent />); await dormir(80); });
        estat.reinicios++;
      } else {
        // PC reinicia (com a tela na lista de comandas)
        if (comandaAtiva != null) { historico.push("X"); await apertarX(80); }
        historico.push("REINICIO");
        await act(async () => { root.unmount(); });
        await A.__simularReinicioParaTeste(); await A.carregarArmazem();
        comandaAtiva = null;
        root = createRoot(document.getElementById("root")!);
        await act(async () => { root.render(<Parent />); await dormir(80); });
        estat.reinicios++;
      }
    } catch (e: any) { falha(`excecao: ${e?.message || e}`); }
  }
  // Fim do turno: fecha TODAS as comandas que ainda têm algo lançado e confere
  if (MODO === "online") banco.latencia = 150;
  for (let tentativa = 0; tentativa < 3; tentativa++) {
    for (const [n, m] of modelo) {
      if (![...m.values()].some(q => q > 0)) continue;
      historico.push(`fim: abre ${n}`);
      if (comandaAtiva != null) await apertarX(80);
      for (const c of String(n)) await passo(8, () => press(c));
      await passo(MODO === "online" ? 900 : 350, () => press("Enter"));
      await conferirTela(`fim do turno, comanda ${n}`);
      await fecharConta(false);
    }
  }
  const naoFechou = [...modelo.entries()].filter(([, m]) => [...m.values()].some(q => q > 0)).map(([n]) => n);
  if (naoFechou.length) falha(`fim do turno: comanda(s) ${naoFechou.join(",")} nao fecharam em 3 tentativas`);
  if (MODO === "offline") {
    const sobrou = A.pedidosAbertosLocais().filter(o => (o.items || []).length);
    if (sobrou.length) falha(`fim do turno: sobrou comanda aberta no disco: ${sobrou.map(o => o.table_number).join(",")}`);
    if (banco.orders.length) falha(`o banco foi chamado ${banco.orders.length} vez(es) -- comanda devia ser 100% local`);
  } else {
    const sobrou = abertosNoBanco().filter((o: any) => (o.items || []).length);
    if (sobrou.length) falha(`fim do turno: sobrou pedido aberto no banco: comandas ${sobrou.map((o: any) => o.table_number).join(",")}`);
  }
  await act(async () => { root.unmount(); });
}

(async () => {
  const S = Number(env.SESSOES || 12), P = Number(env.PASSOS || 60);
  for (let s = 1; s <= S; s++) {
    await sessao(s, P);
    g.process.stdout.write(`sessao ${s}/${S}: ${problemas.length} problema(s) ate agora\n`);
  }
  const ms = estat.f7ms.sort((a, b) => a - b);
  g.process.stdout.write(`\nACOES: ${estat.acoes} | vendas fechadas: ${estat.vendas} (F8: ${estat.f8}) | codigos: ${estat.codigos} | pesos: ${estat.pesos} | trocas de comanda: ${estat.trocas} | Enters: ${estat.enters} | apagados: ${estat.apagados} | reinicios: ${estat.reinicios} | peso recusado sem comanda: ${estat.recusasSemComanda}\n`);
  g.process.stdout.write(`F7 (ms): mediana ${ms[Math.floor(ms.length / 2)] ?? "-"} | pior ${ms[ms.length - 1] ?? "-"} (${MODO === "offline" ? "OFFLINE, banco falso a 3000 ms" : "ONLINE, banco a 30/150/600 ms"}) | fechamentos barrados pela trava (seguros, refeitos depois): ${estat.bloqueios} | F7 sem achar a comanda na lista: ${estat.f7SemAbrir}\n`);
  g.process.stdout.write(`\nPROBLEMAS: ${problemas.length}\n${problemas.slice(0, 12).map(p => " - " + p).join("\n")}\n`);
  g.process.exit(problemas.length ? 1 : 0);
})();
