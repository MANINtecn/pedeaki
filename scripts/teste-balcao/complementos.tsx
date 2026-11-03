// Modal de complementos por passos do site (21/10/2026) -- sorvetes 275/276/277 com os tipos do SQL.
//   ENTRY=complementos.tsx OUT=complementos.cjs node build.cjs && NODE_PATH=$PWD/node_modules node complementos.cjs
import "./prelude";
import React from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { ModalComplementos, montarEtapas, produtoTemPassos } from "@novo/components/ModalComplementos";

const g: any = globalThis;
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
let falhas = 0;
const ok = (c: boolean, msg: string) => { console.log((c ? "  ok   " : "  FALHA ") + msg); if (!c) falhas++; };

const ad = (id: string, name: string, price: number, tipoComplemento?: any, extra: any = {}) => ({ id, name, price, isAvailable: true, tipoComplemento, ...extra });
const sabores = ["Flocos", "Morango", "Ninho Trufado"].map((n, i) => ad("s" + i, n, 0, "sabor"));
const pote: any = { id: 275, name: "Potes de Sorvete 1,8L", price: 30, categoryId: 1, isAvailable: true,
  selectedAddons: [...sabores, ad("a1", "Amendoim", 3, "adicional"), ad("a2", "Bis", 3, "adicional")] };
const kitCalda: any = { id: 277, name: "sorvete + cascão + calda", price: 45, categoryId: 1, isAvailable: true,
  selectedAddons: [...sabores, ad("c1", "calda chocolate", 0, "opcional"), ad("c2", "calda morango", 0, "opcional"), ad("a3", "Granola", 2, "adicional"), ad("x1", "Velho sem tipo", 5)] };
const antigo: any = { id: 1, name: "Açaí 500", price: 20, selectedAddons: [ad("g", "Granola", 0), ad("l", "Leite", 2)] };

// --- regras puras
ok(produtoTemPassos(pote) && produtoTemPassos(kitCalda), "produto com item tipado abre o passo a passo");
ok(!produtoTemPassos(antigo), "produto sem tipo continua no modal antigo");
ok(montarEtapas(pote).map(e => e.tipo).join() === "sabor,adicional", "pote: Sabor -> Adicionais (sem passo vazio)");
ok(montarEtapas(kitCalda).map(e => e.tipo).join() === "sabor,opcional,adicional", "kit calda: Sabor -> Opcionais -> Adicionais");
ok(montarEtapas(kitCalda)[2].itens.some(a => a.id === "x1"), "item sem tipo pago cai em Adicionais");
const inativo: any = { ...pote, selectedAddons: [...pote.selectedAddons, ad("s9", "Esgotado", 0, "sabor", { isAvailable: false })] };
ok(!montarEtapas(inativo)[0].itens.some(a => a.id === "s9"), "sabor indisponível não aparece");

// --- tela
const div = document.createElement("div"); document.body.appendChild(div);
const root = createRoot(div);
const tid = (t: string) => document.querySelector(`[data-testid="${t}"]`) as HTMLElement | null;
const clicar = async (t: string) => { const el = tid(t); if (!el) throw new Error("sem " + t); await act(async () => { el.click(); }); };
const titulo = () => tid("titulo-passo")?.textContent || "";

async function cenario(nome: string, item: any, fn: (carrinho: any[], fechou: () => boolean) => Promise<void>) {
  console.log(nome);
  const carrinho: any[] = []; let fechado = false;
  await act(async () => { root.render(<ModalComplementos key={nome} item={item} onAddToCart={(c: any) => carrinho.push(c)} onClose={() => { fechado = true; }} />); });
  await fn(carrinho, () => fechado);
}

(async () => {
  await cenario("C1 pote: sabor obrigatório, pula adicionais, R$ 30", pote, async (car) => {
    ok(titulo() === "Escolha o sabor", "abre no passo do sabor");
    ok((tid("avancar") as HTMLButtonElement).disabled, "não avança sem sabor");
    await clicar("opcao-s0"); await clicar("opcao-s1");
    ok(document.querySelectorAll(".bg-purple-500").length === 1, "sabor é escolha única (trocou Flocos por Morango)");
    await clicar("avancar");
    ok(titulo() === "Adicionais" && tid("avancar")!.textContent === "Não quero, continuar", "adicionais pode pular");
    await clicar("avancar");
    ok(!!tid("resumo") && tid("adicionar")!.textContent!.includes("30,00"), "resumo R$ 30,00");
    await clicar("adicionar");
    ok(car.length === 1 && car[0].selectedAddons.length === 1 && car[0].selectedAddons[0].name === "Morango" && car[0].quantity === 1, "carrinho: 1 pote Morango");
    ok(!!tid("adicionado") && !!tid("outro-sabor"), "tela Adicionado com + outro sabor");
  });

  await cenario("C2 dois sabores = 2 unidades = R$ 60 (bug do pedido WEB de 18/10)", pote, async (car) => {
    await clicar("opcao-s0"); await clicar("avancar"); await clicar("avancar"); await clicar("adicionar");
    await clicar("outro-sabor");
    ok(titulo() === "Escolha o sabor" && !document.querySelector(".bg-purple-500"), "+ outro sabor recomeça limpo");
    await clicar("opcao-s2"); await clicar("avancar"); await clicar("avancar"); await clicar("adicionar");
    const total = car.reduce((s, c) => s + (c.price + c.selectedAddons.reduce((x: number, a: any) => x + a.price, 0)) * c.quantity, 0);
    ok(car.length === 2 && total === 60, `2 linhas, total R$ ${total} (esperado 60)`);
  });

  await cenario("C3 kit calda: calda grátis + 2 adicionais, quantidade 2", kitCalda, async (car) => {
    await clicar("opcao-s0"); await clicar("avancar");
    ok(titulo() === "Opcionais", "passo Opcionais (calda inclusa)");
    await clicar("opcao-c2"); await clicar("avancar");
    await clicar("opcao-a3"); await clicar("opcao-x1"); await clicar("avancar");
    await clicar("mais");
    ok(tid("adicionar")!.textContent!.includes("104,00"), `(45+2+5) x 2 = R$ 104,00 -> ${tid("adicionar")!.textContent}`);
    await clicar("adicionar");
    ok(car[0].quantity === 2 && car[0].selectedAddons.map((a: any) => a.id).join() === "s0,c2,a3,x1", "itens na ordem sabor, opcional, adicionais");
  });

  await cenario("C4 kit SEM calda não obriga calda paga (bug do pedido WEB de 11/10)", pote, async (car) => {
    await clicar("opcao-s1"); await clicar("avancar"); await clicar("avancar"); await clicar("adicionar");
    ok(car[0].selectedAddons.every((a: any) => a.price === 0), "levou só o sabor, nada pago");
  });

  await cenario("C5 voltar e desmarcar adicional", kitCalda, async (car) => {
    await clicar("opcao-s0"); await clicar("avancar"); await clicar("avancar");
    await clicar("opcao-a3"); await clicar("opcao-a3"); await clicar("avancar");
    await clicar("voltar"); await clicar("voltar"); await clicar("voltar");
    ok(titulo() === "Escolha o sabor", "voltou até o sabor");
    await clicar("avancar"); await clicar("avancar"); await clicar("avancar"); await clicar("adicionar");
    ok(car[0].selectedAddons.length === 1, "só o sabor (adicional desmarcado)");
  });

  await cenario("C6 fechar", pote, async (_c, fechou) => { await clicar("fechar"); ok(fechou(), "X fecha"); });

  await act(async () => root.unmount());
  console.log(falhas ? `\n${falhas} FALHA(S)` : "\nTUDO OK");
  process.exit(falhas ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
