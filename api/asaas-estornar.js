/**
 * Devolve o dinheiro (estorno do PIX, com o split desfeito) de um pedido online PAGO que o lojista cancelou ou recusou.
 *
 * Quem chama: o painel do lojista, logo depois de cancelar o pedido. Cabeçalho Authorization com o login dele.
 * Segurança: o pedido só é lido com o login do próprio lojista (as regras do banco só mostram os pedidos da loja dele),
 * então quem não é dono da loja recebe "não encontrado". Pedido que não é online, não foi pago ou já foi estornado
 * não faz nada (pode chamar de novo sem risco). O pedido precisa estar Cancelado.
 */
import { criarClientes } from './_asaas.js';

export async function tratar({ authorization, corpo, env, buscar }) {
    const orderId = corpo && corpo.order_id;
    if (!orderId || typeof orderId !== 'string' || !/^Bearer .{20,}/.test(authorization || '')) return { status: 401, corpo: { erro: 'negado' } };
    const base = env.SUPABASE_URL || env.VITE_SUPABASE_URL;
    const anon = env.SUPABASE_ANON_KEY || env.VITE_SUPABASE_ANON_KEY;

    // 1. Leitura com o login do lojista: se ele nao e dono da loja, a lista vem vazia.
    const r = await buscar(`${base}/rest/v1/orders?id=eq.${encodeURIComponent(orderId)}&select=id`, { headers: { apikey: anon, Authorization: authorization } });
    const lista = r.ok ? await r.json().catch(() => []) : [];
    if (!Array.isArray(lista) || lista.length !== 1) return { status: 404, corpo: { erro: 'Pedido nao encontrado.' } };

    // 2. A partir daqui, chave de servico.
    const { sup, asaas } = criarClientes(env, buscar);
    const [o] = await sup(`/rest/v1/orders?id=eq.${encodeURIComponent(orderId)}&select=id,status,payment_status,asaas_payment_id`);
    if (!o) return { status: 404, corpo: { erro: 'Pedido nao encontrado.' } };
    if (!o.asaas_payment_id || o.payment_status !== 'pago') return { status: 200, corpo: { estornado: false, motivo: 'nada a estornar' } };
    if (o.status !== 'Cancelado') return { status: 409, corpo: { erro: 'Cancele o pedido antes de estornar.' } };

    try {
        await asaas(`/payments/${o.asaas_payment_id}/refund`, 'POST', { description: 'Pedido cancelado pela loja' });
    } catch (e) {
        // Estorno recusado (ex.: saldo da conta do Asaas menor que o valor): fica marcado para o Super Admin resolver na mao.
        await sup(`/rest/v1/orders?id=eq.${encodeURIComponent(orderId)}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ payment_status: 'estorno_pendente' }) });
        await sup(`/rest/v1/pagamentos?asaas_payment_id=eq.${encodeURIComponent(o.asaas_payment_id)}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'ESTORNO_FALHOU', atualizado_em: new Date().toISOString() }) });
        console.error('asaas-estornar recusado', e.message);
        return { status: 409, corpo: { estornado: false, erro: 'O Asaas recusou o estorno. A plataforma foi avisada e vai devolver o valor.' } };
    }
    await sup(`/rest/v1/orders?id=eq.${encodeURIComponent(orderId)}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ payment_status: 'estornando' }) });
    await sup(`/rest/v1/pagamentos?asaas_payment_id=eq.${encodeURIComponent(o.asaas_payment_id)}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'ESTORNO_SOLICITADO', atualizado_em: new Date().toISOString() }) });
    return { status: 200, corpo: { estornado: true } };
}

export default async function handler(req, res) {
    if (req.method !== 'POST') { res.status(405).json({ erro: 'metodo' }); return; }
    try {
        const r = await tratar({ authorization: req.headers.authorization, corpo: typeof req.body === 'string' ? JSON.parse(req.body) : req.body, env: process.env, buscar: fetch });
        res.status(r.status).json(r.corpo);
    } catch (e) {
        console.error('asaas-estornar', e.message);
        res.status(502).json({ erro: 'Nao foi possivel estornar agora. Tente de novo em instantes.' });
    }
}
