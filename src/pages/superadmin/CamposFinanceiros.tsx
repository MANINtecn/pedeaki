import React from 'react';
import type { FormFinanceiro } from './util';

/** Campos das condições financeiras da loja de comissão (usados na criação, na edição e nos padrões da plataforma). */
export const CamposFinanceiros: React.FC<{ v: FormFinanceiro; onChange: (v: FormFinanceiro) => void; comDebito?: boolean; comCarteira?: boolean }> = ({ v, onChange, comDebito, comCarteira }) => {
    const campo = 'w-full bg-gray-700 border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-blue-500';
    const num = (k: keyof FormFinanceiro) => (e: React.ChangeEvent<HTMLInputElement>) => onChange({ ...v, [k]: parseFloat(e.target.value) || 0 });
    return (
        <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Comissão, entrega do lojista (%)</label>
                    <input type="number" step="0.5" min="0" max="100" value={v.comissao_pct_propria} onChange={num('comissao_pct_propria')} className={campo} />
                </div>
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Comissão, entrega do app (%)</label>
                    <input type="number" step="0.5" min="0" max="100" value={v.comissao_pct_app} onChange={num('comissao_pct_app')} className={campo} />
                </div>
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Parte fixa por pedido (R$)</label>
                    <input type="number" step="0.01" min="0" value={v.comissao_fixa} onChange={num('comissao_fixa')} className={campo} />
                </div>
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Limite de débito do dinheiro (R$)</label>
                    <input type="number" step="1" min="0" value={v.limite_debito} onChange={num('limite_debito')} className={campo} />
                </div>
            </div>
            <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                <input type="checkbox" checked={v.repassa_taxa_pagamento} onChange={e => onChange({ ...v, repassa_taxa_pagamento: e.target.checked })} className="h-4 w-4" />
                Repassar ao lojista a taxa do pagamento online (cartão e PIX)
            </label>
            {comCarteira && (
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Carteira do lojista no Asaas (walletId): libera o PIX online da loja</label>
                    <input type="text" value={v.asaas_wallet_id || ''} onChange={e => onChange({ ...v, asaas_wallet_id: e.target.value.trim() || null })} placeholder="00000000-0000-0000-0000-000000000000" className={campo} />
                    {v.asaas_wallet_id && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v.asaas_wallet_id) && (
                        <p className="text-xs text-red-400 mt-1">Esse código não parece um walletId (são 36 caracteres com hífens). Confira no Asaas.</p>
                    )}
                    <p className="text-xs text-gray-500 mt-1">Nunca use a carteira do Pede Aki aqui. Vazio: a loja segue com o PIX de chave e comprovante.</p>
                </div>
            )}
            {comDebito && (
                <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1">Débito atual do dinheiro (R$): ajuste manual depois que o lojista pagar</label>
                    <input type="number" step="0.01" min="0" value={v.debito_dinheiro} onChange={num('debito_dinheiro')} className={campo} />
                </div>
            )}
            <p className="text-xs text-gray-500">Pedidos pagos em dinheiro viram débito de comissão. Quando o débito chega ao limite, a opção Dinheiro some do checkout daquela loja.</p>
        </div>
    );
};
