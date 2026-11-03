// Segundo peso sumido (sexta 09/10/2026, pedido #165): dois pesos na mesma comanda, F7 em momentos diferentes.
// Mede o que o AdminPage mede no fechamento: total da TELA (soma da lista local) x total/itens do BANCO.
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

const categories: any[] = [{ id: 1, name: "Milk" }, { id: 3, name: "Acai" }];
const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [{ ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] }];
const settings: any = { balcaoV2: true, isScaleEnabled: false, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

const ENV: any = (g.process && g.process.env) || {};
const LAT_ATUALIZA = Number(ENV.LAT_ATUALIZA || 200); // recarregarSoPedidos do AdminPage

let ativaRef: any[] = [];          // = ordersRef do AdminPage (lista LOCAL que o F7 usa pro total)
let enviarRef: any = null;         // = enviarComandaAtivaRef do AdminPage
let semAtualizar = false;          // simula lista local desatualizada (tempo real atrasado)

const Parent = () => {
  const [active, setActive] = useState<any[]>([]);
  ativaRef = active;
  const ref = useRef<any>(null);
  enviarRef = ref;
  const onOrderComplete = async (order: any) => {
    if (order.id) await updateOrder(order.id, order); else await criarNoBanco(order);
    await dormir(LAT_ATUALIZA);
    if (!semAtualizar) setActive(abertos());
  };
  return <CounterTab categories={categories} menuItems={menuItems} addons={[]} settings={settings} storeId="s1" onOrderComplete={onOrderComplete}
    activeOrders={active} enviarComandaAtivaRef={ref} />;
};

const press = (key: string, alvo: any = w) => alvo.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms = 60, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
const soma = (os: any[]) => os.reduce((s, o) => s + (Number(o.total) || 0), 0);
const somaItens = (os: any[]) => os.reduce((s, o) => s + (o.items || []).reduce((a: number, i: any) => a + (Number(i.price) || 0) * (Number(i.quantity) || 1), 0), 0);
const pesosNoBanco = (n: number) => banco.orders.filter((o: any) => Number(o.table_number) === n && !["Cancelado"].includes(o.status)).flatMap((o: any) => (o.items || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg));

async function abrirComanda(n: string) { for (const c of n) await passo(10, () => press(c)); await passo(500, () => press("Enter")); }
async function lancarPeso(kg: string) {
  await passo(80, () => press("b"));
  const input = document.querySelector('input[placeholder^="Digite o peso"]') as any;
  if (!input) { console.log("   (modal do peso nao abriu)"); return; }
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, "value")!.set!;
    setter.call(input, kg); input.dispatchEvent(new w.Event("input", { bubbles: true })); await dormir(20);
  });
  await act(async () => { press("Enter", input); await dormir(30); });
}

/** O que o F7 do AdminPage faz ate abrir o checkout: envia a comanda e depois monta o total pela lista LOCAL. */
async function f7(n: number) {
  const ok = enviarRef.current ? await enviarRef.current() : true;
  const locais = ativaRef.filter((o: any) => Number(o.table_number) === n);
  return { ok, totalTela: soma(locais), itensTela: locais.flatMap((o: any) => o.items || []).filter((i: any) => i.weightKg).length };
}

let falhas = 0;
async function cenario(nome: string, corpo: () => Promise<{ esperaPesos: number[] }>) {
  banco.orders = []; banco.seq = 0; banco.falhas = 0; ativaRef = []; semAtualizar = false; g.__alertas = [];
  w.localStorage.clear();
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(50); });
  console.log(`\n=== ${nome}`);
  const { esperaPesos } = await corpo();
  await dormir(1500);
  const noBanco = pesosNoBanco(2);
  const totalBanco = soma(banco.orders.filter((o: any) => Number(o.table_number) === 2));
  const itensBanco = somaItens(banco.orders.filter((o: any) => Number(o.table_number) === 2));
  const perdeu = esperaPesos.some(p => !noBanco.includes(p)) || noBanco.length !== esperaPesos.length;
  const diverge = Math.abs(totalBanco - itensBanco) > 0.02;
  console.log(`   pesos lancados: [${esperaPesos.join(", ")}] | pesos no banco: [${noBanco.join(", ")}] | total banco R$${totalBanco.toFixed(2)} x soma itens R$${itensBanco.toFixed(2)}`);
  console.log(`   pedidos: ${banco.orders.map((o: any) => `${o.id}[${o.status}] ${(o.items || []).length}it R$${o.total}`).join(" | ") || "(vazio)"}`);
  console.log(`   RESULTADO: ${perdeu ? "PERDEU PESO  <<<<<<" : "ok"}${diverge ? "  | TOTAL != ITENS <<<<<<" : ""}`);
  if (perdeu || diverge) falhas++;
  await act(async () => { root.unmount(); });
}

(async () => {
  await cenario("P1) peso1 -> envia (Enter) -> reabre comanda -> peso2 -> F7 IMEDIATO (mesmo instante)", async () => {
    await abrirComanda("2"); await lancarPeso("0.212");
    await dormir(600); await passo(40, () => press("Enter")); await dormir(1500);
    await abrirComanda("2"); await lancarPeso("0.202");
    const r: any = await f7(2);
    console.log(`   F7: ok=${r.ok} | total da TELA R$${r.totalTela.toFixed(2)} (${r.itensTela} peso(s) na lista local)`);
    return { esperaPesos: [0.212, 0.202] };
  });
  await cenario("P2) peso1 -> envia -> reabre -> peso2 -> espera 100 ms -> F7", async () => {
    await abrirComanda("2"); await lancarPeso("0.212");
    await dormir(600); await passo(40, () => press("Enter")); await dormir(1500);
    await abrirComanda("2"); await lancarPeso("0.202"); await dormir(100);
    const r: any = await f7(2);
    console.log(`   F7: ok=${r.ok} | total da TELA R$${r.totalTela.toFixed(2)} (${r.itensTela} peso(s) na lista local)`);
    return { esperaPesos: [0.212, 0.202] };
  });
  await cenario("P3) peso1 e peso2 na MESMA comanda, so carrinho, F7 (nunca enviada)", async () => {
    await abrirComanda("2"); await lancarPeso("0.212"); await lancarPeso("0.202");
    const r: any = await f7(2);
    console.log(`   F7: ok=${r.ok} | total da TELA R$${r.totalTela.toFixed(2)} (${r.itensTela} peso(s) na lista local)`);
    return { esperaPesos: [0.212, 0.202] };
  });
  await cenario("P4) peso1 -> Enter (envia) e JA lanca peso2 antes do envio terminar -> F7", async () => {
    await abrirComanda("2"); await lancarPeso("0.212");
    await dormir(600); await passo(5, () => press("Enter")); await lancarPeso("0.202");
    const r: any = await f7(2);
    console.log(`   F7: ok=${r.ok} | total da TELA R$${r.totalTela.toFixed(2)} (${r.itensTela} peso(s) na lista local)`);
    return { esperaPesos: [0.212, 0.202] };
  });
  await cenario("P5) igual P1, mas lista LOCAL atrasada (tempo real nao chegou) antes do F7", async () => {
    await abrirComanda("2"); await lancarPeso("0.212");
    await dormir(600); await passo(40, () => press("Enter")); await dormir(1500);
    await abrirComanda("2"); await lancarPeso("0.202");
    semAtualizar = true;
    const r: any = await f7(2);
    console.log(`   F7: ok=${r.ok} | total da TELA R$${r.totalTela.toFixed(2)} (${r.itensTela} peso(s) na lista local)`);
    return { esperaPesos: [0.212, 0.202] };
  });
  // ---- F7 NAO pode bloquear fluxo normal (a trava so vale quando ha item de verdade sem salvar) ----
  const digitar = async (cod: string) => { for (const c of cod) await passo(5, () => press(c)); await passo(40); };
  const f7normal = async (nome: string, corpo: () => Promise<void>, esperaOk: boolean, esperaPedidos: number, esperaQtd?: number) => {
    banco.orders = []; banco.seq = 0; ativaRef = []; semAtualizar = false; w.localStorage.clear();
    const root = createRoot(document.getElementById("root")!);
    await act(async () => { root.render(<Parent />); await dormir(50); });
    await corpo();
    const r: any = await f7(3);
    await dormir(800);
    const n = banco.orders.filter((o: any) => Number(o.table_number) === 3).length;
    const qtd = banco.orders.filter((o: any) => Number(o.table_number) === 3).flatMap((o: any) => o.items || []).reduce((a: number, i: any) => a + (Number(i.quantity) || 1), 0);
    const bom = r.ok === esperaOk && n === esperaPedidos && (esperaQtd === undefined || qtd === esperaQtd);
    console.log(`\n=== ${nome}\n   F7 ok=${r.ok} (esperado ${esperaOk}) | pedidos da comanda 3 no banco: ${n} (esperado ${esperaPedidos}) | unidades: ${qtd}\n   RESULTADO: ${bom ? "ok" : "FALHOU  <<<<<<"}`);
    if (!bom) falhas++;
    await act(async () => { root.unmount(); });
  };
  await f7normal("Q1) comanda nova, 1 produto, F7 (nunca enviada)", async () => { await abrirComanda("3"); await digitar("103"); }, true, 1);
  await f7normal("Q2) comanda ja enviada, reabre SEM mudar nada, F7 (nao pode criar pedido novo)", async () => {
    await abrirComanda("3"); await digitar("103"); await dormir(600); await passo(40, () => press("Enter")); await dormir(1500); await abrirComanda("3");
  }, true, 1);
  await f7normal("Q3) comanda ja enviada, reabre, lanca o MESMO produto de novo (soma quantidade), F7", async () => {
    await abrirComanda("3"); await digitar("103"); await dormir(600); await passo(40, () => press("Enter")); await dormir(1500); await abrirComanda("3"); await digitar("103");
  }, true, 1, 2);
  await f7normal("Q4) peso + produto na mesma comanda, F7", async () => { await abrirComanda("3"); await lancarPeso("0.300"); await digitar("103"); }, true, 1);

  console.log(`\nFALHAS: ${falhas}`);
  process.exit(falhas ? 1 : 0);
})();
