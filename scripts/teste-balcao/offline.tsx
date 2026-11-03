// Balcão V2 OFFLINE com o CounterTab REAL (15/10/2026). O "AdminPage" daqui faz o mesmo que o real
// no modo offline: comanda grava no armazém local, F7 fecha local. O banco falso fica LENTO (3 s)
// de propósito: se qualquer coisa do fechamento esperasse a internet, o F7 levaria segundos.
//   ENTRY=offline.tsx OUT=offline.cjs node build.cjs && NODE_PATH=$PWD/node_modules node offline.cjs
import "./prelude";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import * as A from "@proj/offline/armazemBalcao";
import { definirContextoBalcao } from "@proj/services/comandaBackend";
import { banco } from "./stub-supabase";

const g: any = globalThis; const w: any = g.window;
const disco: { texto: string | null } = { texto: null };
w.electron = { balcao: {
  carregar: async () => disco.texto,
  salvar: async (t: string) => { disco.texto = t; return { ok: true }; },
  diario: async () => true, log: async () => true, espacoLivre: async () => 1e12,
} };
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
const _log = console.log; console.log = (...a: any[]) => { if (String(a[0]).startsWith("[Balcao]")) return; _log(...a); };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));

const categories: any[] = [{ id: 1, name: "Milk" }, { id: 3, name: "Acai" }];
const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [
  { ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] },
  { ...base, id: 333, name: "ADD 3", price: 3, categoryId: 3, codigo: 333, allowedAddons: [] },
];
const settings: any = { balcaoV2: true, isScaleEnabled: false, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let enviarRef: any = null;
let comandaAtiva: number | null = null;
let setSinal: any = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [sinal, _setSinal] = useState(0); setSinal = _setSinal;
  useEffect(() => A.assinarArmazem(() => setVer(v => v + 1)), []);
  const ref = useRef<any>(null); enviarRef = ref;
  // = handleCounterOrderComplete do AdminPage no modo offline
  const onOrderComplete = async (order: any) => {
    if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order);
    else await A.criarPedidoLocal(order);
  };
  return <CounterTab categories={categories} menuItems={menuItems} addons={[]} settings={settings} storeId="s1"
    onOrderComplete={onOrderComplete} activeOrders={A.pedidosAbertosLocais()} enviarComandaAtivaRef={ref} fecharComandaSignal={sinal} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};

const press = (key: string, alvo: any = w) => alvo.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms = 60, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
async function abrirComanda(n: string) { for (const c of n) await passo(10, () => press(c)); await passo(300, () => press("Enter")); }
async function digitar(cod: string) { for (const c of cod) await passo(5, () => press(c)); await passo(40); }
async function lancarPeso(kg: string) {
  await passo(80, () => press("b"));
  const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
  if (!input) { _log("   (modal do peso nao abriu)"); return; }
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, "value")!.set!;
    setter.call(input, kg); input.dispatchEvent(new w.Event("input", { bubbles: true })); await dormir(20);
  });
  await act(async () => { press("Enter", input); await dormir(30); });
}
/** O F7 do AdminPage no modo offline: envia o que falta (local) e fecha a comanda local. Fora do act, como no app. */
async function f7(n: number, forma = "Dinheiro") {
  const t0 = Date.now();
  if (comandaAtiva == null) return { ok: false, r: { ok: false }, ms: 0, semComanda: true } as any;
  const ok = enviarRef.current ? await enviarRef.current() : true;
  const ps = A.pedidosAbertosDaComanda(n);
  const total = Number(ps.reduce((s, o) => s + (Number(o.total) || 0), 0).toFixed(2));
  const r: any = ok && ps.length ? await A.fecharComandaLocal(n, total, { method: forma, amountTendered: total, discount: 0, tax: 0, finalTotal: total }) : { ok: false };
  const ms = Date.now() - t0;
  await act(async () => { setSinal((v: number) => v + 1); await dormir(30); });
  return { ok, r, ms };
}

let falhas = 0;
const confere = (nome: string, cond: boolean, extra = "") => { _log(`   ${cond ? "ok  " : "FALHOU"} ${nome}${extra ? "  -> " + extra : ""}`); if (!cond) falhas++; };
const pesosDaUltimaVenda = () => { const f = A.vendasNaFila(); const v = f[f.length - 1]; return v ? v.itens.filter((i: any) => i.weightKg).map((i: any) => i.weightKg) : []; };

async function cenario(nome: string, corpo: () => Promise<void>) {
  A.__reiniciarArmazemParaTeste(true); definirContextoBalcao(true); disco.texto = null;
  banco.orders = []; banco.seq = 0; banco.latencia = 3000; w.localStorage.clear();
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(50); });
  _log(`\n=== ${nome}`);
  await corpo();
  confere("nenhuma chamada ao banco (comanda e fechamento 100% locais)", banco.orders.length === 0);
  await act(async () => { root.unmount(); });
}

(async () => {
  await cenario("O1) peso1 -> Enter (salva) -> reabre -> peso2 -> F7 imediato", async () => {
    await abrirComanda("2"); await lancarPeso("0.212"); await dormir(300); await passo(40, () => press("Enter")); await dormir(200);
    await abrirComanda("2"); await lancarPeso("0.202");
    const r = await f7(2);
    confere("venda com os DOIS pesos", JSON.stringify(pesosDaUltimaVenda().sort()) === JSON.stringify([0.202, 0.212]), JSON.stringify(pesosDaUltimaVenda()));
    confere("F7 fechou em menos de 300 ms com o banco a 3 s", r.ms < 300, `${r.ms} ms`);
    confere("comanda 2 liberada", A.pedidosAbertosDaComanda(2).length === 0);
  });
  await cenario("O2) peso1 -> Enter (fecha a comanda) e JA confirma peso2 sem comanda -> recusa; reabre, pesa, F7", async () => {
    await abrirComanda("2"); await lancarPeso("0.212"); await dormir(300);
    await passo(5, () => press("Enter")); await lancarPeso("0.202");
    const carrinhoFantasma = document.querySelectorAll('button[title="Remover item"]').length;
    const semComanda = await f7(2);
    confere("peso sem comanda recusado (nao entra em carrinho invisivel)", carrinhoFantasma === 0 && (semComanda as any).semComanda === true, );
    confere("comanda 2 continua salva com o 1o peso", JSON.stringify(A.pedidosAbertosDaComanda(2).flatMap(o => (o.items||[]).map((i: any) => i.weightKg))) === "[0.212]");
    await abrirComanda("2"); await lancarPeso("0.202");
    const r = await f7(2);
    confere("venda com os DOIS pesos", JSON.stringify(pesosDaUltimaVenda().sort()) === JSON.stringify([0.202, 0.212]), JSON.stringify(pesosDaUltimaVenda()));
    confere("F7 rapido", r.ms < 300, );
  });
  await cenario("O3) dois pesos so no carrinho -> F7", async () => {
    await abrirComanda("3"); await lancarPeso("0.300"); await lancarPeso("0.150");
    const r = await f7(3, "PIX");
    confere("venda com os dois pesos, PIX", JSON.stringify(pesosDaUltimaVenda().sort()) === JSON.stringify([0.15, 0.3]) && A.vendasNaFila()[0]?.pagamentos[0]?.forma === "PIX");
    confere("F7 rapido", r.ms < 300, `${r.ms} ms`);
  });
  await cenario("O4) produto + 6 Enters seguidos (reenvio fantasma) -> F7: item NAO duplica", async () => {
    await abrirComanda("4"); await digitar("103"); await dormir(300);
    for (let i = 0; i < 6; i++) await passo(25, () => press("Enter"));
    await dormir(300);
    await abrirComanda("4");
    await f7(4);
    const v = A.vendasNaFila()[0];
    const unidades = (v?.itens || []).reduce((s: number, i: any) => s + (i.quantity || 1), 0);
    confere("venda com 1 milk-shake de R$ 15", unidades === 1 && v?.total === 15, `unidades=${unidades} total=${v?.total}`);
  });
  await cenario("O5) PC desliga com comanda aberta -> religa -> comanda volta -> F7", async () => {
    await abrirComanda("5"); await digitar("103"); await digitar("333"); await dormir(700); await passo(40, () => press("Enter")); await dormir(200);
    await A.__simularReinicioParaTeste(); await A.carregarArmazem();
    confere("depois de religar: comanda 5 com 2 itens", A.pedidosAbertosDaComanda(5).flatMap(o => o.items || []).length === 2);
    await abrirComanda("5");
    await f7(5);
    confere("venda R$ 18 (15 + 3)", A.vendasNaFila()[0]?.total === 18, `${A.vendasNaFila()[0]?.total}`);
  });
  await cenario("O6) comanda aberta, todos os itens removidos, Enter -> comanda some, sem venda", async () => {
    await abrirComanda("6"); await digitar("103"); await dormir(300); await passo(40, () => press("Enter")); await dormir(200);
    await abrirComanda("6");
    const rem = document.querySelectorAll('button[title="Remover item"]');
    for (const b of Array.from(rem)) await act(async () => { (b as any).click(); await dormir(20); });
    await passo(40, () => press("Enter")); await dormir(200);
    confere("comanda 6 apagada e nenhuma venda criada", A.pedidosAbertosDaComanda(6).length === 0 && A.vendasNaFila().length === 0);
  });

  _log(`\nFALHAS: ${falhas}`);
  g.process.exit(falhas ? 1 : 0);
})();
