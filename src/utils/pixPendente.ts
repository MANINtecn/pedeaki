/**
 * PIX online que o cliente ainda nao pagou: fica guardado no aparelho para a tela de pagamento voltar sozinha
 * se ele sair para o app do banco (o navegador pode recarregar a pagina), ate o prazo de 15 minutos acabar.
 */
export interface PixPendente {
    storeId: string;
    pedido: { id: string; phone: string; total: number; pagarAte?: string | null };
    /** Dados do pedido e do resgate de pontos, para fechar tudo certo quando o PIX cair, mesmo depois de recarregar. */
    orderData: any;
    criado: any;
    resgate: any;
    desconto: number;
    telefoneOriginal: string;
    qr?: { imagem: string; copiaCola: string };
}

const CHAVE = 'pedeaki_pix_pendente';

export function salvarPixPendente(p: PixPendente) {
    try { localStorage.setItem(CHAVE, JSON.stringify(p)); } catch { /* sem armazenamento: a tela so nao volta sozinha */ }
}
export function limparPixPendente() {
    try { localStorage.removeItem(CHAVE); } catch { /* tudo bem */ }
}
/** Devolve o PIX pendente desta loja se ainda estiver no prazo; vencido, apaga e devolve null. De outra loja, so devolve null. */
export function lerPixPendente(storeId: string): PixPendente | null {
    try {
        const bruto = localStorage.getItem(CHAVE);
        if (!bruto) return null;
        const p = JSON.parse(bruto) as PixPendente;
        const limite = p?.pedido?.pagarAte ? new Date(p.pedido.pagarAte).getTime() : 0;
        if (!limite || limite + 30000 < Date.now()) { limparPixPendente(); return null; }
        return p.storeId === storeId ? p : null;
    } catch { return null; }
}
