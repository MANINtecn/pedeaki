// O que cada tipo de loja enxerga (src/services/recursos.ts).
//   ENTRY=recursos.ts OUT=recursos.cjs node build.cjs && node recursos.cjs
import { temRecurso, tipoDaLoja, cobraMensalidade, abaLiberada, RECURSO_DA_ABA, ROTULO_DO_TIPO } from "@proj/services/recursos";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

igual("T1 loja sem o campo modelo (antiga) é PDV completo", tipoDaLoja({}), "pdv_avancado");
igual("T2 loja ainda não carregada não esconde nada", [tipoDaLoja(null), tipoDaLoja(undefined)], ["pdv_avancado", "pdv_avancado"]);
igual("T3 comissão", tipoDaLoja({ modelo: "comissao", plan: null }), "comissao");
igual("T4 comissão ignora um plano que sobrou no cadastro", tipoDaLoja({ modelo: "comissao", plan: "avancado" }), "comissao");
igual("T5 PDV básico", tipoDaLoja({ modelo: "pdv", plan: "basico" }), "pdv_basico");
igual("T6 PDV avançado", tipoDaLoja({ modelo: "pdv", plan: "avancado" }), "pdv_avancado");
igual("T7 PDV sem plano definido não perde recurso", tipoDaLoja({ modelo: "pdv", plan: null }), "pdv_avancado");

const com = { modelo: "comissao" as const, plan: null }, bas = { modelo: "pdv" as const, plan: "basico" as const }, ava = { modelo: "pdv" as const, plan: "avancado" as const };
for (const r of ["balcao", "caixa", "cozinha", "comandos", "fidelidade", "sorteio", "propagandas", "robo_whatsapp", "nota_fiscal"] as const)
  ok(`C ${r} fica escondido na loja de comissão`, temRecurso(com, r) === false);
for (const r of ["pedidos", "cardapio", "promocoes", "historico", "motoboys", "taxas_entrega", "configuracoes", "avaliacoes"] as const)
  ok(`C ${r} aparece na loja de comissão`, temRecurso(com, r) === true);
ok("B PDV básico tem balcão e caixa", temRecurso(bas, "balcao") && temRecurso(bas, "caixa"));
ok("B PDV básico NÃO tem nota fiscal nem robô", !temRecurso(bas, "nota_fiscal") && !temRecurso(bas, "robo_whatsapp"));
ok("A PDV avançado tem tudo", (Object.keys(RECURSO_DA_ABA)).every(a => abaLiberada(ava, a)));
ok("A o avançado é sempre superconjunto do básico, que é superconjunto da comissão", Object.keys(RECURSO_DA_ABA).every(a => (!abaLiberada(com, a) || abaLiberada(bas, a)) && (!abaLiberada(bas, a) || abaLiberada(ava, a))));

igual("M comissão não cobra mensalidade", cobraMensalidade(com), false);
igual("M PDV cobra", [cobraMensalidade(bas), cobraMensalidade(ava)], [true, true]);
ok("X aba fora da tabela (addons) nunca é bloqueada", abaLiberada(com, "addons") === true);
igual("R rótulos", [ROTULO_DO_TIPO.comissao, ROTULO_DO_TIPO.pdv_basico, ROTULO_DO_TIPO.pdv_avancado], ["Comissão", "PDV Básico", "PDV Avançado"]);

console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
process.exit(falhas ? 1 : 0);
