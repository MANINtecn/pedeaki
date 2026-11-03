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

async function abrirComanda(h: any, n: string) { for (const c of n) await h.passo(10, () => h.press(c)); await h.passo(500, () => h.press("Enter")); }
async function lancarPesoManual(h: any, kg: string) {
  await h.passo(80, () => h.press("b"));
  const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
  if (!input) { console.log("   (modal do peso nao abriu)"); return; }
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(h.w.HTMLInputElement.prototype, "value")!.set!;
    setter.call(input, kg); input.dispatchEvent(new h.w.Event("input", { bubbles: true })); await dormir(20);
  });
  await act(async () => { press("Enter", input); await dormir(30); });
}
(async () => {
  await cenario("D) Comanda 1 completa e enviada; depois Comanda 2: produtos + peso manual + Enters", async (h) => {
    await abrirComanda(h, "1");
    await digitar(h, "103"); await digitar(h, "333"); await digitar(h, "420");
    await lancarPesoManual(h, "0.250");
    await h.dormir(700); await h.passo(40, () => h.press("Enter")); await h.dormir(1500);
    console.log("   comanda 1 enviada. banco: " + h.resumoBanco() + " | carrinho agora=" + h.linhasCarrinho());
    await abrirComanda(h, "2");
    await digitar(h, "103"); await digitar(h, "333"); await digitar(h, "420");
    console.log("   comanda 2 aberta, 3 produtos: carrinho=" + h.linhasCarrinho());
    await lancarPesoManual(h, "0.250");
    console.log("   comanda 2 apos peso manual: carrinho=" + h.linhasCarrinho());
    await h.dormir(700);
    for (let i = 0; i < 5; i++) await h.passo(30, () => h.press("Enter"));
    await h.dormir(1500);
  });
  await cenario("E) Comanda 1 aberta e ABANDONADA (rascunho) -> Comanda 2 com peso manual + Enters", async (h) => {
    await abrirComanda(h, "1");
    await digitar(h, "103"); await digitar(h, "333");
    await abrirComanda(h, "2");
    await digitar(h, "103"); await digitar(h, "333"); await digitar(h, "420");
    await lancarPesoManual(h, "0.250");
    console.log("   comanda 2 apos peso manual: carrinho=" + h.linhasCarrinho());
    await h.dormir(700);
    for (let i = 0; i < 5; i++) await h.passo(30, () => h.press("Enter"));
    await h.dormir(1500);
  });
  await cenario("F) Comanda 2 direto (sem passar pela 1): produtos + peso manual + 5 Enters", async (h) => {
    await abrirComanda(h, "2");
    await digitar(h, "103"); await digitar(h, "333"); await digitar(h, "420");
    await lancarPesoManual(h, "0.250");
    await h.dormir(700);
    for (let i = 0; i < 5; i++) await h.passo(30, () => h.press("Enter"));
    await h.dormir(1500);
  });
  process.exit(0);
})();
