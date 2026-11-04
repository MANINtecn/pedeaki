import React, { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import type { Store } from '../../types';
import { chamarAdmin, useLogins } from './logins';

const campo = 'w-full bg-gray-700 border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-blue-500';
const botao = 'px-3 py-2 rounded-lg text-sm font-bold transition disabled:opacity-50';

/** Qual login é o dono desta loja. A pessoa escolhe na lista; criar, trocar senha e apagar logins fica na aba Logins. */
export const AcessoDoDono: React.FC<{ store: Store; onMudou: () => void }> = ({ store, onMudou }) => {
    const { logins, carregando, erro, recarregar } = useLogins();
    const [escolhido, setEscolhido] = useState(store.owner_id || '');
    const [ocupado, setOcupado] = useState(false);
    const [aviso, setAviso] = useState<{ tipo: 'ok' | 'erro'; texto: string } | null>(null);

    useEffect(() => { setEscolhido(store.owner_id || ''); }, [store.owner_id]);

    const atual = logins.find(l => l.id === store.owner_id);
    const executar = async (corpo: Record<string, unknown>, sucesso: string) => {
        setOcupado(true); setAviso(null);
        try { await chamarAdmin({ ...corpo, store_id: store.id }); setAviso({ tipo: 'ok', texto: sucesso }); onMudou(); recarregar(); }
        catch (e: any) { setAviso({ tipo: 'erro', texto: e?.message || 'Não foi possível concluir.' }); }
        finally { setOcupado(false); }
    };

    return (
        <div className="rounded-lg border border-gray-700 p-4 space-y-3">
            <p className="text-sm font-bold text-blue-300">Login desta loja</p>
            <p className="text-xs text-gray-400">
                {store.owner_id ? <>Quem entra no painel: <span className="text-gray-200">{atual?.email || store.owner_email || '(login ligado)'}</span></> : <span className="text-yellow-300">Nenhum login ligado a esta loja.</span>}
            </p>
            {erro && <p className="text-xs text-red-300">{erro}</p>}
            <select value={escolhido} onChange={e => setEscolhido(e.target.value)} className={campo} disabled={carregando}>
                <option value="">{carregando ? 'Carregando logins...' : 'Escolha um login'}</option>
                {logins.map(l => (
                    <option key={l.id} value={l.id}>
                        {l.email}{l.lojas.length ? ` (já usado em: ${l.lojas.map(x => x.nome).join(', ')})` : ' (livre)'}
                    </option>
                ))}
            </select>
            <div className="flex flex-wrap gap-2">
                <button type="button" disabled={ocupado || !escolhido || escolhido === store.owner_id} onClick={() => executar({ acao: 'vincular', user_id: escolhido }, 'Login ligado a esta loja.')} className={`${botao} bg-green-600 hover:bg-green-700 text-white`}>Ligar este login</button>
                {store.owner_id && <button type="button" disabled={ocupado} onClick={() => { if (confirm('Soltar o login desta loja? O dono perde o acesso ao painel, mas o login continua existindo.')) executar({ acao: 'desvincular' }, 'Login solto da loja.'); }} className={`${botao} bg-yellow-700 hover:bg-yellow-600 text-white`}>Soltar login</button>}
            </div>
            {aviso && <p className={`text-sm ${aviso.tipo === 'ok' ? 'text-green-300' : 'text-red-300'}`}>{aviso.texto}</p>}
            <p className="text-xs text-gray-500">Precisa de um login novo, trocar senha ou apagar? Use a aba <NavLink to="/super-admin/logins" className="text-blue-400 underline">Logins</NavLink>.</p>
        </div>
    );
};
