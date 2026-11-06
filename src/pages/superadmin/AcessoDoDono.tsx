import React, { useEffect, useState } from 'react';
import type { Store } from '../../types';
import { chamarAdmin, gerarSenha, useLogins } from './logins';

const campo = 'w-full bg-gray-700 border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-blue-500';
const botao = 'px-3 py-2 rounded-lg text-sm font-bold transition border border-gray-500 text-gray-100 hover:bg-gray-700 hover:border-gray-300 disabled:opacity-50 disabled:hover:bg-transparent';

type Painel = null | 'senha' | 'email' | 'novo' | 'existente';

/** Tudo do login do dono, dentro da loja: criar, ligar um que já existe, trocar senha e e-mail, soltar e excluir. */
export const AcessoDoDono: React.FC<{ store: Store; onMudou: () => void }> = ({ store, onMudou }) => {
    const { logins, carregando, erro, recarregar } = useLogins();
    const atual = logins.find(l => l.id === store.owner_id);
    const emailAtual = atual?.email || store.owner_email || '';
    const protegido = !!atual?.administrador;

    const [painel, setPainel] = useState<Painel>(null);
    const [email, setEmail] = useState('');
    const [senha, setSenha] = useState('');
    const [escolhido, setEscolhido] = useState('');
    const [ocupado, setOcupado] = useState(false);
    const [aviso, setAviso] = useState<{ tipo: 'ok' | 'erro'; texto: string } | null>(null);
    const [entregar, setEntregar] = useState<{ email: string; senha: string } | null>(null);

    useEffect(() => { setPainel(null); setEscolhido(''); setEntregar(null); setAviso(null); }, [store.id]);

    const abrir = (p: Painel) => { setPainel(p); setEmail(p === 'email' ? emailAtual : ''); setSenha(''); setEscolhido(''); setAviso(null); setEntregar(null); };

    const executar = async (corpo: Record<string, unknown>, sucesso: string, depois?: () => void) => {
        setOcupado(true); setAviso(null);
        try { await chamarAdmin(corpo); setAviso({ tipo: 'ok', texto: sucesso }); depois?.(); onMudou(); recarregar(); }
        catch (e: any) { setAviso({ tipo: 'erro', texto: e?.message || 'Não foi possível concluir.' }); }
        finally { setOcupado(false); }
    };

    const criar = () => executar({ acao: 'criar', store_id: store.id, email, senha }, 'Login criado e ligado à loja. Já pode entrar.',
        () => { setEntregar({ email: email.trim().toLowerCase(), senha }); setPainel(null); });
    const trocarSenha = () => executar({ acao: 'senha', user_id: store.owner_id, senha }, 'Senha trocada.',
        () => { setEntregar({ email: emailAtual, senha }); setPainel(null); });
    const trocarEmail = () => executar({ acao: 'email', user_id: store.owner_id, email }, 'E-mail de login trocado.', () => setPainel(null));
    const ligar = () => executar({ acao: 'vincular', store_id: store.id, user_id: escolhido }, 'Login ligado a esta loja.', () => setPainel(null));
    const soltar = () => { if (confirm('Soltar o login desta loja? O dono perde o acesso ao painel, mas o login continua existindo.')) executar({ acao: 'desvincular', store_id: store.id }, 'Login solto da loja.'); };
    const excluir = () => {
        const outras = (atual?.lojas || []).filter(l => l.id !== store.id).map(l => l.nome);
        const extra = outras.length ? ` Atenção: este login também é dono de ${outras.join(', ')}, que ficará sem dono.` : '';
        if (confirm(`Excluir o login ${emailAtual}? A conta é apagada de vez e não dá para desfazer. A loja continua existindo, pronta para outro login.${extra}`)) executar({ acao: 'excluir', user_id: store.owner_id }, 'Login excluído. A loja está sem dono.');
    };

    const link = `${window.location.origin}/${store.slug}/admin`;
    const pacote = entregar ? `Acesso ao painel da sua loja no Pede Aki\nEndereço: ${link}\nLogin: ${entregar.email}\nSenha: ${entregar.senha}` : '';
    const livres = logins.filter(l => l.id !== store.owner_id);

    const campoSenha = (
        <div className="flex gap-2">
            <input type="text" value={senha} onChange={e => setSenha(e.target.value)} className={campo} placeholder="Senha (mínimo 8 caracteres)" autoComplete="off" />
            <button type="button" onClick={() => setSenha(gerarSenha())} className={`${botao} whitespace-nowrap`}>Gerar</button>
        </div>
    );

    return (
        <div className="rounded-lg border border-gray-700 p-4 space-y-3">
            <p className="text-sm font-bold text-blue-300">Login do dono</p>
            {erro && <p className="text-xs text-red-300">{erro}</p>}
            {store.owner_id ? (
                <p className="text-sm text-gray-200 break-all">
                    {carregando && !emailAtual ? 'Carregando...' : emailAtual || '(login ligado)'}
                    {protegido && <span className="ml-2 px-2 py-0.5 rounded text-xs font-bold bg-purple-900 text-purple-200">administrador</span>}
                </p>
            ) : (
                <p className="text-sm text-yellow-300">Esta loja ainda não tem login.</p>
            )}

            <div className="flex flex-wrap gap-2">
                {store.owner_id && atual && !protegido && <>
                    <button type="button" disabled={ocupado} onClick={() => abrir('senha')} className={`${botao}`}>Trocar senha</button>
                    <button type="button" disabled={ocupado} onClick={() => abrir('email')} className={`${botao}`}>Trocar e-mail</button>
                </>}
                {store.owner_id && <button type="button" disabled={ocupado} onClick={soltar} className={`${botao}`}>Soltar</button>}
                {store.owner_id && atual && !protegido && <button type="button" disabled={ocupado} onClick={excluir} className={`${botao}`}>Excluir login</button>}
                <button type="button" disabled={ocupado} onClick={() => abrir('novo')} className={`${botao}`}>{store.owner_id ? 'Novo login' : 'Criar login'}</button>
                <button type="button" disabled={ocupado || carregando || livres.length === 0} onClick={() => abrir('existente')} className={`${botao}`}>Usar um que já existe</button>
            </div>

            {painel === 'senha' && (
                <div className="space-y-2">{campoSenha}
                    <div className="flex gap-2"><button type="button" disabled={ocupado} onClick={trocarSenha} className={`${botao}`}>Confirmar nova senha</button><button type="button" onClick={() => setPainel(null)} className={`${botao}`}>Cancelar</button></div>
                </div>
            )}
            {painel === 'email' && (
                <div className="space-y-2">
                    <input type="email" value={email} onChange={e => setEmail(e.target.value)} className={campo} autoComplete="off" />
                    <p className="text-xs text-gray-500">A senha continua a mesma. O dono passa a entrar com o e-mail novo.</p>
                    <div className="flex gap-2"><button type="button" disabled={ocupado} onClick={trocarEmail} className={`${botao}`}>Confirmar novo e-mail</button><button type="button" onClick={() => setPainel(null)} className={`${botao}`}>Cancelar</button></div>
                </div>
            )}
            {painel === 'novo' && (
                <div className="space-y-2">
                    {store.owner_id && <p className="text-xs text-yellow-300">Esta loja já tem login. Criar um novo troca o dono; o login antigo continua existindo, solto.</p>}
                    <input type="email" value={email} onChange={e => setEmail(e.target.value)} className={campo} placeholder="Login (e-mail, pode ser de fachada)" autoComplete="off" />
                    {campoSenha}
                    <div className="flex gap-2"><button type="button" disabled={ocupado} onClick={criar} className={`${botao}`}>Criar e ligar</button><button type="button" onClick={() => setPainel(null)} className={`${botao}`}>Cancelar</button></div>
                </div>
            )}
            {painel === 'existente' && (
                <div className="space-y-2">
                    <select value={escolhido} onChange={e => setEscolhido(e.target.value)} className={campo}>
                        <option value="">Escolha um login</option>
                        {livres.map(l => <option key={l.id} value={l.id}>{l.email}{l.lojas.length ? ` (já usado em: ${l.lojas.map(x => x.nome).join(', ')})` : ' (livre)'}</option>)}
                    </select>
                    <div className="flex gap-2"><button type="button" disabled={ocupado || !escolhido} onClick={ligar} className={`${botao}`}>Ligar este login</button><button type="button" onClick={() => setPainel(null)} className={`${botao}`}>Cancelar</button></div>
                </div>
            )}

            {aviso && <p className={`text-sm ${aviso.tipo === 'ok' ? 'text-green-300' : 'text-red-300'}`}>{aviso.texto}</p>}
            <button type="button" disabled={ocupado} onClick={() => executar({ acao: 'teste' }, 'Chave de serviço aceita pelo Supabase.')} className="text-xs text-gray-500 hover:text-gray-300 underline">Testar a chave de serviço</button>
            {entregar && (
                <div className="rounded-lg bg-gray-900 border border-gray-600 p-3 space-y-2">
                    <p className="text-xs text-gray-400">Dados para enviar ao cliente (somem quando você fechar esta janela):</p>
                    <pre className="text-sm text-gray-100 whitespace-pre-wrap break-all">{pacote}</pre>
                    <button type="button" onClick={() => { navigator.clipboard?.writeText(pacote).catch(() => {}); setAviso({ tipo: 'ok', texto: 'Dados copiados.' }); }} className={`${botao}`}>Copiar dados</button>
                </div>
            )}
        </div>
    );
};
