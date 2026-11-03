// Itens de uma comanda aparecendo em OUTRA (achado pela bateria pico.tsx, 15/10/2026).
// Hipótese: trocar de comanda rápido (X, C, C / número) salva o rascunho com o NÚMERO novo e o
// CARRINHO antigo, porque o carrinho da comanda nova chega um instante depois.
// Roda nos dois modos:  MODO=offline (armazém local)  |  MODO=online (banco falso com latência, = V2 de hoje)
//   ENTRY=troca.tsx OUT=troca.cjs node build.cjs && MODO=online NODE_PATH=$PWD/node_modules node troca.cjs
import "./prelude";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import * as A from "@proj/offline/armazemBalcao";
import { definirContextoBalcao } from "@proj/services/comandaBackend";
import { banco, criarNoBanco, updateOrder } from "./stub-supabase";

const g: any = globalThis; const w: any = g.window;
const MODO = (g.process?.env?.MODO || "offline") as "offline" | "online";
const disco: { texto: string | null } = { texto: null };
if (MODO === "offline") w.electron = { balcao: { carregar: async () => disco.texto, salvar: async (t: string) => { disco.texto = t; return { ok: true }; }, diario: async () => true, log: async () => true, espacoLivre: async () => 1e12 } };
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
const _log = console.log; console.log = (...a: any[]) => { if (String(a[0]).startsWith("[Balcao]")) return; _log(...a); };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const clone = (x: any) => JSON.parse(JSON.stringify(x));
const abertos = () => clone(banco.orders.filter((o: any) => !["Entregue", "Cancelado"].includes(o.status)));

const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [{ ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] }, { ...base, id: 222, name: "AGUA", price: 4, categoryId: 1, codigo: 222, allowedAddons: [] }];
const settings: any = { balcaoV2: true, isScaleEnabled: false, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let comandaAtiva: number | null = null; let setAtivosRef: any = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [ativos, setAtivos] = useState<any[]>([]); setAtivosRef = setAtivos;
  useEffect(() => MODO === "offline" ? A.assinarArmazem(() => setVer(v => v + 1)) : undefined, []);
  const ref = useRef<any>(null);
  const onOrderComplete = async (order: any) => {
    if (MODO === "offline") { if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order); else await A.criarPedidoLocal(order); return; }
    if (order.id) await updateOrder(order.id, order); else await criarNoBanco(order);
    await dormir(200); setAtivos(abertos());
  };
  return <CounterTab categories={[{ id: 1, name: "Milk" }]} menuItems={menuItems} addons={[]} settings={settings} storeId="s1" onOrderComplete={onOrderComplete}
    activeOrders={MODO === "offline" ? A.pedidosAbertosLocais() : ativos} enviarComandaAtivaRef={ref} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};
const press = (key: string, alvo: any = w) => alvo.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms: number, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
const tela = () => Array.from(document.querySelectorAll('button[title="Remover item"]')).map(b => (b.parentElement!.querySelector("span")?.childNodes[0]?.textContent || "").trim());
async function abre(n: string) { for (const c of n) await passo(8, () => press(c)); await passo(400, () => press("Enter")); }
async function cod(c: string) { for (const k of c) await passo(5, () => press(k)); await passo(60); }

let falhas = 0;
async function cenario(nome: string, corpo: () => Promise<void>) {
  A.__reiniciarArmazemParaTeste(MODO === "offline"); definirContextoBalcao(true); disco.texto = null;
  banco.orders = []; banco.seq = 0; banco.latencia = 150; w.localStorage.clear(); comandaAtiva = null;
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(50); });
  _log(`\n=== [${MODO}] ${nome}`);
  await corpo();
  await act(async () => { root.unmount(); });
}
const confere = (nome: string, ok: boolean, extra = "") => { _log(`   ${ok ? "ok  " : "FALHOU"} ${nome}${extra ? "  -> " + extra : ""}`); if (!ok) falhas++; };

(async () => {
  for (const ritmo of [0, 30, 120]) {
    await cenario(`comanda 6 com MILK+AGUA (sem enviar) -> X -> C -> C (pausa ${ritmo} ms) -> confere todas`, async () => {
      await abre("6"); await cod("103"); await cod("222");
      await passo(60, () => press("x"));
      await passo(ritmo, () => press("c"));
      const primeira = comandaAtiva;
      await passo(ritmo, () => press("c"));
      const segunda = comandaAtiva;
      await passo(400);
      _log(`   C abriu ${primeira}, depois ${segunda}`);
      for (const n of [1, 2, 3, 4, 5, 6]) {
        if (comandaAtiva != null) await passo(60, () => press("x"));
        await abre(String(n));
        const t = tela();
        if (n === 6) confere(`comanda 6 tem os 2 itens dela`, t.length === 2, JSON.stringify(t));
        else confere(`comanda ${n} vazia`, t.length === 0, JSON.stringify(t));
      }
    });
  }
  await cenario("comanda 6 com itens -> digita 5+Enter, 1+Enter, 4+Enter rapido (de dentro da comanda)", async () => {
    await abre("6"); await cod("103"); await cod("103");
    for (const n of ["5", "1", "4"]) { await passo(5, () => press(n)); await passo(20, () => press("Enter")); }
    await passo(400);
    for (const n of [1, 4, 5, 6]) {
      if (comandaAtiva != null) await passo(60, () => press("x"));
      await abre(String(n));
      const t = tela();
      if (n === 6) confere("comanda 6 tem o MILK x2 dela", t.length === 1, JSON.stringify(t));
      else confere(`comanda ${n} vazia`, t.length === 0, JSON.stringify(t));
    }
  });
  _log(`\nFALHAS: ${falhas}`);
  g.process.exit(falhas ? 1 : 0);
})();
