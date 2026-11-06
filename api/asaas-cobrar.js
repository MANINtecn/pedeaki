/**
 * Cria a cobrança PIX (com split para o lojista) de um pedido online que está "Aguardando pagamento".
 *
 * Quem chama: a tela de pagamento do cliente, depois de criar o pedido com criar_pedido_online.
 * Corpo: { order_id, phone, cpf }. O telefone precisa bater com o do pedido (mesma checagem da tela de status).
 * Devolve: { pagamento_id, qr_imagem (base64), copia_cola, valor, pagar_ate }.
 * Chamar de novo para o mesmo pedido devolve o mesmo QR (não cria cobrança duplicada).
 */
import { criarClientes, contaDoPedido, documentoValido, foneCanonico, r2 } from './_asaas.js';

const hojeBR = () => new Date(Date.now() - 3 * 3600 * 1000).toISOString().slice(0, 10);

export async function tratar({ corpo, env, buscar }) {
    const { order_id: orderId, phone, cpf } = corpo || {};
    if (!orderId || typeof orderId !== 'string' || !phone) return { status: 400, corpo: { erro: 'Dados incompletos.' } };
    const doc = documentoValido(cpf);
    if (!doc) return { status: 400, corpo: { erro: 'CPF ou CNPJ invalido.' } };
    if (!env.ASAAS_API_KEY) return { status: 500, corpo: { erro: 'Pagamento indisponivel.' } };

    const { sup, asaas } = criarClientes(env, buscar);
    const id = encodeURIComponent(orderId);
    const [o] = await sup(`/rest/v1/orders?id=eq.${id}&select=id,store_id,total,delivery_fee,phone,customer_name,status,payment_status,pagar_ate,asaas_payment_id`);
    if (!o || foneCanonico(o.phone) !== foneCanonico(phone)) return { status: 404, corpo: { erro: 'Pedido nao encontrado.' } };
    if (o.status !== 'Aguardando pagamento' || o.payment_status !== 'aguardando') return { status: 409, corpo: { erro: 'Este pedido nao esta aguardando pagamento.' } };
    if (o.pagar_ate && new Date(o.pagar_ate).getTime() < Date.now()) return { status: 409, corpo: { erro: 'O tempo para pagar acabou. Faca o pedido de novo.' } };

    // Cobrança já criada: devolve o mesmo QR.
    if (o.asaas_payment_id) {
        const qr = await asaas(`/payments/${o.asaas_payment_id}/pixQrCode`);
        return { status: 200, corpo: { pagamento_id: o.asaas_payment_id, qr_imagem: qr.encodedImage, copia_cola: qr.payload, valor: r2(o.total), pagar_ate: o.pagar_ate } };
    }

    const [fin] = await sup(`/rest/v1/loja_financeiro?store_id=eq.${o.store_id}&select=asaas_wallet_id,comissao_pct_propria,comissao_fixa,repassa_taxa_pagamento`);
    if (!fin || !fin.asaas_wallet_id) return { status: 409, corpo: { erro: 'Esta loja ainda nao aceita pagamento online.' } };
    if (fin.asaas_wallet_id === env.ASAAS_WALLET_PLATAFORMA) return { status: 500, corpo: { erro: 'Configuracao da loja invalida.' } };

    const conta = contaDoPedido({ total: o.total, frete: o.delivery_fee, cond: fin });
    if (!(conta.repasseLojista > 0) || conta.repasseLojista >= conta.total) return { status: 409, corpo: { erro: 'Valor do pedido invalido para pagamento online.' } };

    const cliente = await asaas('/customers', 'POST', { name: String(o.customer_name || 'Cliente Pede Aki').slice(0, 100), cpfCnpj: doc, mobilePhone: String(o.phone || '').replace(/\D/g, '').slice(-11) || undefined, externalReference: foneCanonico(o.phone) });
    const cobranca = await asaas('/payments', 'POST', {
        customer: cliente.id, billingType: 'PIX', value: conta.total, dueDate: hojeBR(),
        description: `Pedido Pede Aki`, externalReference: String(o.id),
        split: [{ walletId: fin.asaas_wallet_id, fixedValue: conta.repasseLojista }],
    });
    const qr = await asaas(`/payments/${cobranca.id}/pixQrCode`);

    await sup('/rest/v1/pagamentos', {
        method: 'POST',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ order_id: String(o.id), store_id: o.store_id, asaas_payment_id: cobranca.id, meio: 'PIX', valor: conta.total, comissao: conta.comissao, taxa_estimada: conta.taxa, repasse_lojista: conta.repasseLojista, status: 'PENDENTE', pix_copia_cola: qr.payload }),
    });
    await sup(`/rest/v1/orders?id=eq.${id}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ asaas_payment_id: cobranca.id }) });

    return { status: 200, corpo: { pagamento_id: cobranca.id, qr_imagem: qr.encodedImage, copia_cola: qr.payload, valor: conta.total, pagar_ate: o.pagar_ate } };
}

export default async function handler(req, res) {
    if (req.method !== 'POST') { res.status(405).json({ erro: 'metodo' }); return; }
    try {
        const r = await tratar({ corpo: typeof req.body === 'string' ? JSON.parse(req.body) : req.body, env: process.env, buscar: fetch });
        res.status(r.status).json(r.corpo);
    } catch (e) {
        console.error('asaas-cobrar', e.message);
        res.status(502).json({ erro: 'Nao foi possivel gerar o PIX agora. Tente de novo.' });
    }
}
