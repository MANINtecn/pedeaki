// AUDITOR DO DIÁRIO DO BALCÃO (20/10/2026) -- "caixa-preta" da 1.0.97.
// Segue CADA peso desde que entrou na tela até o destino: salvo, vendido, apagado pela atendente, comanda
// excluída. Peso sem destino = PESO PERDIDO, com a linha do tempo da comanda para achar a causa.
//   node auditar-diario.cjs "C:/Users/icaro/OneDrive/Área de Trabalho/diario-2026-10.jsonl" [AAAA-MM-DD]
const fs = require('fs');
const arq = process.argv[2];
const soDia = process.argv[3] || null;
if (!arq) { console.log('uso: node auditar-diario.cjs <diario.jsonl> [AAAA-MM-DD]'); process.exit(2); }
const tz = { timeZone: 'America/Sao_Paulo' };
const hora = t => new Date(t).toLocaleTimeString('pt-BR', tz);
const dia = t => new Date(t).toLocaleDateString('sv-SE', tz);
const L = fs.readFileSync(arq, 'utf8').split(/\r?\n/).filter(Boolean).map(l => { try { return JSON.parse(l); } catch (_) { return null; } }).filter(Boolean)
  .filter(e => !soDia || dia(e.em) === soDia);

const temId = (e, id) => {
  if (Array.isArray(e.ids) && e.ids.includes(id)) return true;
  if (Array.isArray(e.itens) && e.itens.some(i => i && i.cartId === id)) return true;
  const sufixo = '#' + String(id).slice(-6);
  return ['tela', 'salvos', 'rascunho'].some(k => Array.isArray(e[k]) && e[k].some(x => String(x).endsWith(sufixo)));
};

const pesos = L.map((e, i) => ({ e, i })).filter(x => x.e.tipo === 'peso-na-tela');
const res = { vendido: 0, salvo: 0, apagado: 0, excluida: 0, rascunho: 0, perdido: [] };
for (const { e: p, i } of pesos) {
  const depois = L.slice(i + 1);
  const vendido = depois.find(e => (e.tipo === 'venda-fechada' || e.tipo === 'venda-enviada') && temId(e, p.id));
  const salvo = depois.find(e => (e.tipo === 'item-salvo' || e.tipo === 'comanda-atualizada') && temId(e, p.id));
  const apagado = depois.find(e => e.tipo === 'item-removido-da-tela' && e.id === p.id);
  const ultimaVez = [...depois].reverse().find(e => temId(e, p.id)); // última vez que o peso aparece em qualquer registro
  const excluida = depois.find(e => e.tipo === 'pedido-apagado' && Number(e.comanda) === Number(p.comanda) && new Date(e.em) >= new Date((ultimaVez || p).em));
  if (vendido) { res.vendido++; continue; }
  if (apagado) { res.apagado++; continue; }
  if (excluida && !salvo) { res.excluida++; continue; }
  if (salvo) {
    // salvo mas não vendido: ou a comanda segue aberta, ou foi excluída depois, ou o peso saiu de uma regravação
    const regravouSemEle = depois.find(e => (e.tipo === 'comanda-atualizada') && Number(e.comanda) === Number(p.comanda) && new Date(e.em) > new Date(salvo.em) && Array.isArray(e.ids) && !e.ids.includes(p.id) && !depois.some(x => x.tipo === 'item-removido-da-tela' && x.id === p.id));
    const fechou = depois.find(e => e.tipo === 'venda-fechada' && Number(e.comanda) === Number(p.comanda) && new Date(e.em) > new Date(salvo.em));
    if (fechou || regravouSemEle) { res.perdido.push({ p, motivo: fechou ? 'foi SALVO, mas a comanda FECHOU sem ele' : 'foi SALVO e depois a comanda foi regravada SEM ele' }); continue; }
    if (excluida) { res.excluida++; continue; }
    res.salvo++; continue;
  }
  const ultimoRascunho = [...depois].reverse().find(e => (e.tipo === 'rascunho-salvo' || e.tipo === 'balcao-saiu-com-pendente') && temId(e, p.id));
  const fechouDepois = depois.find(e => e.tipo === 'venda-fechada' && Number(e.comanda) === Number(p.comanda));
  if (ultimoRascunho && !fechouDepois) { res.rascunho++; continue; }
  res.perdido.push({ p, motivo: fechouDepois ? 'entrou na TELA e a comanda FECHOU sem ele (nunca foi salvo)' : 'entrou na TELA e nunca foi salvo nem vendido' });
}

console.log(`Diário: ${arq}${soDia ? ' | dia ' + soDia : ''}`);
console.log(`Pesos que entraram na tela: ${pesos.length}`);
console.log(`  vendidos: ${res.vendido} | salvos em comanda ainda aberta: ${res.salvo} | apagados pela atendente: ${res.apagado} | comanda excluída: ${res.excluida} | em rascunho (comanda aberta): ${res.rascunho}`);
console.log(`  PESOS PERDIDOS: ${res.perdido.length}`);
for (const { p, motivo } of res.perdido) {
  console.log(`\n  >>> ${dia(p.em)} ${hora(p.em)} comanda ${p.comanda}: ${Number(p.kg).toFixed(3)} kg (${p.estavel === false ? 'balança oscilando' : 'estável'}) -- ${motivo}`);
  const ini = new Date(p.em).getTime() - 30 * 60000, fim = new Date(p.em).getTime() + 60 * 60000;
  L.filter(e => Number(e.comanda) === Number(p.comanda) && new Date(e.em).getTime() >= ini && new Date(e.em).getTime() <= fim)
    .forEach(e => console.log(`        ${hora(e.em)} ${String(e.tipo).padEnd(26)} ${e.kg !== undefined ? e.kg + 'kg ' : ''}${e.tela ? 'tela=' + JSON.stringify(e.tela) + ' ' : ''}${e.salvos ? 'salvos=' + JSON.stringify(e.salvos) + ' ' : ''}${e.detalhe ? 'gravou=' + JSON.stringify(e.detalhe) : ''}${e.resposta ? 'resposta=' + e.resposta : ''}`));
}
process.exit(res.perdido.length ? 1 : 0);
