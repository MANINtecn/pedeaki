import "./prelude";
import React, { useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import { banco, criarNoBanco, updateOrder } from "./stub-supabase";

const g: any = globalThis; const w: any = g.window;
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const clone = (x: any) => JSON.parse(JSON.stringify(x));
const abertos = () => clone(banco.orders.filter((o: any) => !["Entregue", "Cancelado"].includes(o.status)));

const categories: any[] = [{ id: 1, name: "Milk" }, { id: 2, name: "Picoles" }, { id: 3, name: "Acai" }];
const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [
  { ...base, id: 103, name: "MILK-SHAKE CAFE C NUTELLA 500ML", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] },
  { ...base, id: 333, name: "ADD 3", price: 3, categoryId: 3, codigo: 333, allowedAddons: [] },
  { ...base, id: 420, name: "PICOLES GOURMET", price: 10, categoryId: 2, codigo: 420, allowedAddons: ["a1", "a2"] },
  { ...base, id: 300, name: "POTE 1,8L", price: 30, categoryId: 3, codigo: 300, allowedAddons: ["a1"] },
];
const addons: any[] = [{ id: "a1", name: "Brigadeiro", price: 0, isAvailable: true, categoryId: 2, store_id: "s1" }, { id: "a2", name: "Ninho", price: 0, isAvailable: true, categoryId: 2, store_id: "s1" }];
const settings: any = { balcaoV2: true, isScaleEnabled: false, scalePricePerKg: 60, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let setActiveRef: any = null;
const Parent = () => {
  const [active, setActive] = useState<any[]>([]);
  setActiveRef = setActive;
  const enviarRef = useRef<any>(null);
  const onOrderComplete = async (order: any) => {
    if (order.id) await updateOrder(order.id, order); else await criarNoBanco(order);
    await dormir(200); // recarregarSoPedidos do AdminPage
    setActive(abertos());
  };
  return <CounterTab categories={categories} menuItems={menuItems} addons={addons} settings={settings} storeId="s1" onOrderComplete={onOrderComplete}
    activeOrders={active} enviarComandaAtivaRef={enviarRef} />;
};

const press = (key: string, alvo: any = w) => alvo.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const linhasCarrinho = () => document.querySelectorAll('button[title="Remover item"]').length;
const nomesCarrinho = () => Array.from(document.querySelectorAll('button[title="Remover item"]')).map(b => (b.parentElement?.querySelector("span")?.textContent || "").trim().slice(0, 18));
const resumoBanco = () => banco.orders.map((o: any) => `${o.id}[${o.status}] ${(o.items || []).length} itens R$${o.total}`).join(" | ") || "(vazio)";
const passo = async (ms = 60, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };

export async function cenario(nome: string, corpo: (h: any) => Promise<void>) {
  banco.orders = []; banco.seq = 0; banco.falhas = 0; g.__alertas = [];
  w.localStorage.clear();
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(50); });
  console.log(`\n=== ${nome}`);
  await corpo({ press, passo, linhasCarrinho, nomesCarrinho, resumoBanco, dormir, w });
  console.log(`   FIM: carrinho=${linhasCarrinho()} (${nomesCarrinho().join(", ")}) | banco: ${resumoBanco()} | alertas: ${(g.__alertas || []).length}`);
  await act(async () => { root.unmount(); });
}

async function abrirComanda1(h: any) { await h.passo(10, () => h.press("1")); await h.passo(500, () => h.press("Enter")); }
async function digitar(h: any, cod: string) { for (const c of cod) await h.passo(5, () => h.press(c)); await h.passo(30); if ((globalThis as any).process.env.LEGACY) await h.passo(60, () => h.press("Enter")); }
async function pesoManual(h: any, kg: string) {
  await h.passo(60, () => h.press("b"));
  const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
  if (!input) { console.log("   (modal do peso nao abriu)"); return; }
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(h.w.HTMLInputElement.prototype, "value")!.set!;
    setter.call(input, kg); input.dispatchEvent(new h.w.Event("input", { bubbles: true })); await dormir(20);
  });
  console.log("   [dbg] modal aberto?", document.body.textContent!.includes("Adicionar ao Pedido"), "| valor no campo:", input.value, "| inputs number:", document.querySelectorAll('input[type="number"]').length);
  await act(async () => { press("Enter", input); await dormir(30); });
  console.log("   [dbg] apos Enter no campo -> modal aberto?", document.body.textContent!.includes("Adicionar ao Pedido"), "| alertas:", JSON.stringify((globalThis as any).__alertas || []), "| carrinho:", linhasCarrinho());
}


// ---------- FUZZ: sequencias aleatorias de teclas com tempos aleatorios ----------
let seed = Number((globalThis as any).process.env.SEED || 1);
const rnd = () => { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; };
const pick = <T,>(a: T[]) => a[Math.floor(rnd() * a.length)];
async function digitaCodigo(cod: string, legado: boolean) { for (const c of cod) { await act(async () => { press(c); await dormir(rnd() < 0.3 ? 0 : 8); }); } if (legado) await act(async () => { press("Enter"); await dormir(5); }); }
async function sessao(n: number, legado: boolean) {
  banco.orders = []; banco.seq = 0; banco.falhas = 0; banco.latencia = 40 + Math.floor(rnd() * 300); g.__alertas = []; w.localStorage.clear();
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(30); });
  const log: string[] = []; let adds = 0;
  const acoes = ["codigo", "codigo", "codigo", "enter", "enter", "peso", "comanda", "nome", "x", "mais", "del"];
  for (let k = 0; k < 28; k++) {
    const a = pick(acoes);
    if (a === "codigo") { const c = pick(["103", "333", "420", "300"]); log.push("cod " + c); adds++; await digitaCodigo(c, legado); }
    else if (a === "enter") { const rajada = rnd() < 0.5 ? 1 + Math.floor(rnd() * 6) : 1; log.push("enter x" + rajada); await act(async () => { for (let i = 0; i < rajada; i++) press("Enter"); await dormir(5); }); }
    else if (a === "peso") {
      log.push("peso manual"); adds++;
      await act(async () => { press("b"); await dormir(40); });
      const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
      if (input) {
        await act(async () => { const st = Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, "value")!.set!; st.call(input, "0.250"); input.dispatchEvent(new w.Event("input", { bubbles: true })); await dormir(10); });
        const rajada = 1 + Math.floor(rnd() * 5); log.push("  enter no campo x" + rajada);
        await act(async () => { for (let i = 0; i < rajada; i++) press("Enter", input); await dormir(5); });
      } else adds--;
    }
    else if (a === "comanda") { const c = pick(["1", "2"]); log.push("abre comanda " + c); await act(async () => { press(c); await dormir(5); }); await act(async () => { press("Enter"); await dormir(rnd() < 0.5 ? 30 : 400); }); }
    else if (a === "nome") { log.push("nome"); await act(async () => { press("n"); await dormir(40); }); const ni = document.querySelector('input[placeholder^="Nome do cliente"]') as any; if (ni) { await act(async () => { const st = Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, "value")!.set!; st.call(ni, "teste"); ni.dispatchEvent(new w.Event("input", { bubbles: true })); await dormir(5); }); await act(async () => { press(rnd() < 0.5 ? "Enter" : "Escape", ni); await dormir(10); }); } }
    else if (a === "x") { log.push("x"); await act(async () => { press("x"); await dormir(10); }); }
    else if (a === "mais") { log.push("+"); await act(async () => { press("+"); await dormir(5); }); }
    else if (a === "del") { log.push("del"); await act(async () => { press("Delete"); await dormir(5); }); }
    await dormir(rnd() < 0.4 ? 0 : Math.floor(rnd() * 250));
  }
  await dormir(1200);
  // ---- invariantes ----
  const emCarrinho = linhasCarrinho();
  const itensBanco = banco.orders.filter((o: any) => !["Cancelado"].includes(o.status)).flatMap((o: any) => o.items || []);
  const ids = itensBanco.map((i: any) => i.cartId);
  const repetidosBanco = ids.filter((id: string, ix: number) => ids.indexOf(id) !== ix).length;
  const nomes = nomesCarrinho();
  let problema = "";
  if (emCarrinho > adds + 2) problema = `carrinho explodiu (${emCarrinho} linhas para ${adds} lancamentos)`;
  else if (itensBanco.length > adds + 2) problema = `banco com ${itensBanco.length} itens para ${adds} lancamentos`;
  else if (repetidosBanco > 0) problema = `${repetidosBanco} cartId repetido(s) entre pedidos do banco (duplicata)`;
  await act(async () => { root.unmount(); });
  return { n, problema, adds, emCarrinho, itensBanco: itensBanco.length, pedidos: banco.orders.length, log };
}
(async () => {
  const total = Number((globalThis as any).process.env.N || 20); const legado = !!(globalThis as any).process.env.LEGACY; let ruins = 0;
  for (let n = 1; n <= total; n++) {
    const r = await sessao(n, legado);
    if (r.problema) { ruins++; console.log(`#${n} PROBLEMA: ${r.problema}
   ${r.log.join(" > ")}`); }
  }
  console.log(`
FUZZ: ${total} sessoes, ${ruins} com problema`);
  process.exit(0);
})();
