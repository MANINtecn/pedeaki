import React, { useState } from 'react';
import { usePlataforma } from './dados';
import { Janela, BotaoCancelar, BotaoPrincipal } from './Janela';
import { chamarAdmin, gerarSenha, useLogins, type LoginDaPlataforma } from './logins';

const campo = 'w-full bg-gray-700 border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-blue-500';
const botaoPequeno = 'px-2 py-1 rounded text-xs font-bold transition disabled:opacity-50';

const quando = (iso: string | null) => (iso ? new Date(iso).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : 'nunca entrou');

type Janela_ = null | { tipo: 'novo' } | { tipo: 'senha' | 'email'; login: LoginDaPlataforma };

/** Logins dos donos de loja. Login é uma coisa, loja é outra: aqui se cria, troca e apaga logins; a loja escolhe o dela na lista. */
export const LoginsSecao: React.FC = () => {
    const { stores, recarregar: recarregarLojas } = usePlataforma();
    const { logins, carregando, erro, recarregar } = useLogins();
    const [janela, setJanela] = useState<Janela_>(null);
    const [email, setEmail] = useState('');
    const [senha, setSenha] = useState('');
    const [lojaId, setLojaId] = useState('');
    const [ocupado, setOcupado] = useState(false);
    const [aviso, setAviso] = useState<string | null>(null);
    const [entregar, setEntregar] = useState<{ email: string; senha: string; slug?: string } | null>(null);

    const abrir = (j: Janela_) => { setJanela(j); setEmail(j && j.tipo === 'email' ? j.login.email : ''); setSenha(''); setLojaId(''); setAviso(null); setEntregar(null); };
    const fechar = () => { setJanela(null); setEntregar(null); };
    const atualizar = () => { recarregar(); recarregarLojas(); };

    const rodar = async (corpo: Record<string, unknown>, depois?: () => void) => {
        setOcupado(true); setAviso(null);
        try { await chamarAdmin(corpo); depois?.(); atualizar(); }
        catch (e: any) { setAviso(e?.message || 'Não foi possível concluir.'); }
        finally { setOcupado(false); }
    };

    const criar = () => rodar({ acao: 'criar', email, senha, ...(lojaId ? { store_id: lojaId } : {}) }, () => {
        setEntregar({ email: email.trim().toLowerCase(), senha, slug: stores.find(s => s.id === lojaId)?.slug });
    });
    const trocarSenha = (login: LoginDaPlataforma) => rodar({ acao: 'senha', user_id: login.id, senha }, () => setEntregar({ email: login.email, senha, slug: login.lojas[0]?.slug }));
    const trocarEmail = (login: LoginDaPlataforma) => rodar({ acao: 'email', user_id: login.id, email }, () => fechar());
    const excluir = (login: LoginDaPlataforma) => {
        const lojas = login.lojas.length ? ` As lojas dele (${login.lojas.map(l => l.nome).join(', ')}) continuam existindo, só ficam sem dono até você ligar outro login.` : '';
        if (confirm(`Excluir o login ${login.email}? A conta é apagada de vez e não dá para desfazer.${lojas}`)) rodar({ acao: 'excluir', user_id: login.id });
    };

    const copiar = (t: string) => { navigator.clipboard?.writeText(t).catch(() => {}); setAviso('Dados copiados.'); };
    const dadosCliente = (e: { email: string; senha: string; slug?: string }) =>
        `Acesso ao painel da sua loja no Pede Aqui\n${e.slug ? `Endereço: ${window.location.origin}/${e.slug}/admin\n` : `Endereço: ${window.location.origin}/login\n`}Login: ${e.email}\nSenha: ${e.senha}`;

    const sobDados = entregar && (
        <div className="rounded-lg bg-gray-900 border border-gray-600 p-3 space-y-2 mt-4">
            <p className="text-xs text-gray-400">Dados para enviar ao cliente (somem quando você fechar esta janela):</p>
            <pre className="text-sm text-gray-100 whitespace-pre-wrap break-all">{dadosCliente(entregar)}</pre>
            <button type="button" onClick={() => copiar(dadosCliente(entregar))} className={`${botaoPequeno} bg-gray-600 hover:bg-gray-500 text-white`}>Copiar dados</button>
        </div>
    );

    return (
        <div>
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-3xl font-bold text-white">Logins</h1>
                <button onClick={() => abrir({ tipo: 'novo' })} className="bg-green-600 hover:bg-green-700 px-4 py-2 rounded-lg font-bold transition">Novo login</button>
            </div>
            <p className="text-sm text-gray-400 mb-4">Login é a conta de quem entra no painel. A loja escolhe o login dela na lista, na janela de editar loja. Se alguém sair do sistema, exclua o login: a loja continua pronta para outro.</p>

            {erro && <div className="mb-4 rounded-lg bg-red-900/40 border border-red-700 text-red-200 px-4 py-3 text-sm">{erro}</div>}

            <div className="bg-gray-800 rounded-xl shadow-lg overflow-hidden border border-gray-700">
                <div className="overflow-x-auto">
                    <table className="w-full text-left">
                        <thead className="bg-gray-700 text-gray-300 uppercase text-sm">
                            <tr><th className="p-4">Login</th><th className="p-4">Loja</th><th className="p-4">Último acesso</th><th className="p-4 text-right">Ações</th></tr>
                        </thead>
                        <tbody className="divide-y divide-gray-700">
                            {carregando && <tr><td colSpan={4} className="p-4 text-gray-400">Carregando...</td></tr>}
                            {!carregando && logins.length === 0 && !erro && <tr><td colSpan={4} className="p-4 text-gray-400">Nenhum login ainda.</td></tr>}
                            {logins.map(l => (
                                <tr key={l.id} className="hover:bg-gray-750">
                                    <td className="p-4 text-white font-bold break-all">
                                        {l.email}
                                        {l.administrador && <span className="ml-2 px-2 py-0.5 rounded text-xs font-bold bg-purple-900 text-purple-200">administrador</span>}
                                    </td>
                                    <td className="p-4 text-gray-300">
                                        {l.lojas.length ? l.lojas.map(x => <span key={x.id} className="block">{x.nome} <span className="text-gray-500">/{x.slug}</span></span>) : <span className="text-yellow-300 text-sm">sem loja</span>}
                                    </td>
                                    <td className="p-4 text-gray-400 text-sm">{quando(l.ultimo_acesso)}</td>
                                    <td className="p-4 text-right space-x-2 whitespace-nowrap">
                                        {l.administrador ? <span className="text-xs text-gray-500">protegido</span> : <>
                                            <button onClick={() => abrir({ tipo: 'senha', login: l })} className={`${botaoPequeno} bg-blue-600 hover:bg-blue-700 text-white`}>Trocar senha</button>
                                            <button onClick={() => abrir({ tipo: 'email', login: l })} className={`${botaoPequeno} bg-blue-600 hover:bg-blue-700 text-white`}>Trocar e-mail</button>
                                            <button disabled={ocupado} onClick={() => excluir(l)} className={`${botaoPequeno} bg-red-700 hover:bg-red-600 text-white`}>Excluir</button>
                                        </>}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {janela?.tipo === 'novo' && (
                <Janela titulo="Novo login" onFechar={fechar} rodape={<>
                    <BotaoCancelar rotulo="Fechar" onClick={fechar} />
                    {!entregar && <BotaoPrincipal rotulo={ocupado ? 'Criando...' : 'Criar login'} onClick={criar} />}
                </>}>
                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-400 mb-1">Login (e-mail, pode ser de fachada)</label>
                            <input type="email" value={email} onChange={e => setEmail(e.target.value)} className={campo} placeholder="lanchonete@tecx.pro" autoComplete="off" />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-400 mb-1">Senha (mínimo 8 caracteres)</label>
                            <div className="flex gap-2">
                                <input type="text" value={senha} onChange={e => setSenha(e.target.value)} className={campo} placeholder="Digite ou gere" autoComplete="off" />
                                <button type="button" onClick={() => setSenha(gerarSenha())} className="px-3 rounded-lg bg-gray-600 hover:bg-gray-500 text-white text-sm font-bold">Gerar</button>
                            </div>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-400 mb-1">Ligar a uma loja (opcional)</label>
                            <select value={lojaId} onChange={e => setLojaId(e.target.value)} className={campo}>
                                <option value="">Só criar o login, ligo depois</option>
                                {stores.map(s => <option key={s.id} value={s.id}>{s.name}{s.owner_email ? ` (hoje: ${s.owner_email})` : ' (sem dono)'}</option>)}
                            </select>
                        </div>
                        {aviso && <p className="text-sm text-red-300">{aviso}</p>}
                        {sobDados}
                    </div>
                </Janela>
            )}

            {janela?.tipo === 'senha' && (
                <Janela titulo={`Trocar senha: ${janela.login.email}`} onFechar={fechar} rodape={<>
                    <BotaoCancelar rotulo="Fechar" onClick={fechar} />
                    {!entregar && <BotaoPrincipal rotulo={ocupado ? 'Trocando...' : 'Trocar senha'} onClick={() => trocarSenha(janela.login)} />}
                </>}>
                    <div className="space-y-4">
                        <div className="flex gap-2">
                            <input type="text" value={senha} onChange={e => setSenha(e.target.value)} className={campo} placeholder="Nova senha (mínimo 8)" autoComplete="off" />
                            <button type="button" onClick={() => setSenha(gerarSenha())} className="px-3 rounded-lg bg-gray-600 hover:bg-gray-500 text-white text-sm font-bold">Gerar</button>
                        </div>
                        {aviso && <p className="text-sm text-red-300">{aviso}</p>}
                        {sobDados}
                    </div>
                </Janela>
            )}

            {janela?.tipo === 'email' && (
                <Janela titulo={`Trocar e-mail: ${janela.login.email}`} onFechar={fechar} rodape={<>
                    <BotaoCancelar onClick={fechar} />
                    <BotaoPrincipal rotulo={ocupado ? 'Trocando...' : 'Trocar e-mail'} onClick={() => trocarEmail(janela.login)} />
                </>}>
                    <div className="space-y-4">
                        <input type="email" value={email} onChange={e => setEmail(e.target.value)} className={campo} autoComplete="off" />
                        <p className="text-xs text-gray-500">A senha continua a mesma. O dono passa a entrar com o e-mail novo.</p>
                        {aviso && <p className="text-sm text-red-300">{aviso}</p>}
                    </div>
                </Janela>
            )}
        </div>
    );
};
