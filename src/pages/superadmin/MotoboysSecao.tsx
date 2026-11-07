import React, { useCallback, useEffect, useState } from 'react';
import { supabase } from '../../services/supabaseService';
import { usePlataforma } from './dados';
import { brl, dataHora } from './util';
import { telefoneBonito } from '../../utils/telefoneCliente';

interface Motoboy { id: string; nome: string; telefone: string; wallet_id: string | null; ativo: boolean; online: boolean; online_em: string | null }
interface Repasse { id: string; valor: number; status: 'pendente' | 'pago'; criado_em: string; pago_em: string | null; observacao: string | null; motoboy_id: string }
interface Entrega { id: string; order_id: string; store_id: string; motoboy_id: string | null; status: string; frete: number; motivo: string | null; bloqueada: boolean; tentativas: number; criada_em: string }

const campo = 'w-full bg-gray-700 border-gray-600 rounded-lg p-2 text-white text-sm';
const ROTULO: Record<string, string> = { prevista: 'Prevista', disponivel: 'Disponível', aceita: 'Aceita', retirada: 'A caminho', entregue: 'Entregue', cancelada: 'Cancelada', frustrada: 'Frustrada' };

export const MotoboysSecao: React.FC = () => {
    const d = usePlataforma();
    const [motoboys, setMotoboys] = useState<Motoboy[]>([]);
    const [repasses, setRepasses] = useState<Repasse[]>([]);
    const [entregas, setEntregas] = useState<Entrega[]>([]);
    const [erro, setErro] = useState('');
    const [form, setForm] = useState({ nome: '', telefone: '', senha: '', wallet_id: '' });

    const carregar = useCallback(async () => {
        const [m, r, e] = await Promise.all([
            supabase.from('motoboys_app').select('id,nome,telefone,wallet_id,ativo,online,online_em').order('nome'),
            supabase.from('repasses_motoboy').select('id,valor,status,criado_em,pago_em,observacao,motoboy_id').order('criado_em', { ascending: false }).limit(200),
            supabase.from('entregas_app').select('id,order_id,store_id,motoboy_id,status,frete,motivo,bloqueada,tentativas,criada_em').order('criada_em', { ascending: false }).limit(40),
        ]);
        if (m.error) { setErro('Rode o SQL 18 no Supabase para liberar os motoboys. (' + m.error.message + ')'); return; }
        setErro('');
        setMotoboys((m.data || []) as Motoboy[]);
        setRepasses((r.data || []) as Repasse[]);
        setEntregas((e.data || []) as Entrega[]);
    }, []);
    useEffect(() => { carregar(); const t = setInterval(carregar, 15000); return () => clearInterval(t); }, [carregar]);

    const nomeMoto = (id: string | null) => motoboys.find(m => m.id === id)?.nome || '-';
    const agora = Date.now();
    const noAr = (m: Motoboy) => m.online && !!m.online_em && agora - new Date(m.online_em).getTime() < 3 * 60000;

    const criar = async () => {
        if (!form.nome.trim() || form.telefone.replace(/\D/g, '').length < 10 || form.senha.length < 4) { alert('Preencha o nome, o telefone com DDD e uma senha de pelo menos 4 caracteres.'); return; }
        const { error } = await supabase.from('motoboys_app').insert({ nome: form.nome.trim(), telefone: form.telefone, senha: form.senha, wallet_id: form.wallet_id.trim() || null });
        if (error) { alert('Erro ao cadastrar: ' + (error.message.includes('duplicate') ? 'este telefone já está cadastrado.' : error.message)); return; }
        setForm({ nome: '', telefone: '', senha: '', wallet_id: '' });
        carregar();
    };
    const alternarAtivo = async (m: Motoboy) => { await supabase.from('motoboys_app').update({ ativo: !m.ativo, online: false }).eq('id', m.id); carregar(); };
    const trocarSenha = async (m: Motoboy) => {
        const nova = window.prompt(`Nova senha de ${m.nome} (mínimo 4 caracteres):`);
        if (!nova) return;
        if (nova.length < 4) { alert('Senha curta demais.'); return; }
        const { error } = await supabase.from('motoboys_app').update({ senha: nova }).eq('id', m.id);
        alert(error ? 'Erro: ' + error.message : 'Senha trocada. O motoboy precisa entrar de novo.');
    };
    const pagar = async (ids: string[]) => {
        if (!ids.length || !window.confirm(`Marcar ${ids.length} repasse(s) como pago? Faça o PIX antes.`)) return;
        const { error } = await supabase.from('repasses_motoboy').update({ status: 'pago', pago_em: new Date().toISOString() }).in('id', ids);
        if (error) alert('Erro: ' + error.message);
        carregar();
    };
    const novoCodigo = async (e: Entrega) => {
        if (!window.confirm('Gerar um código novo para o cliente? O antigo deixa de valer e as tentativas voltam a zero.')) return;
        const { error } = await supabase.rpc('entrega_novo_codigo', { p_entrega: e.id });
        alert(error ? 'Erro: ' + error.message : 'Código novo gerado. O cliente vê na tela do pedido.');
        carregar();
    };

    const pendentes = repasses.filter(r => r.status === 'pendente');
    const totalPendente = pendentes.reduce((s, r) => s + Number(r.valor), 0);

    return (
        <div className="space-y-8">
            <div>
                <h1 className="text-3xl font-bold text-white">Motoboys do Pede Aki</h1>
                <p className="text-sm text-gray-400 mt-1">Cadastro, quem está online, entregas e repasse do frete. O motoboy entra em /motoboy com telefone e senha.</p>
            </div>
            {erro && <div className="rounded-lg bg-yellow-900/40 border border-yellow-700 p-3 text-sm text-yellow-200">{erro}</div>}

            <section className="rounded-xl border border-gray-700 p-4 space-y-3">
                <h2 className="font-bold text-white">Cadastrar motoboy</h2>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                    <input className={campo} placeholder="Nome" value={form.nome} onChange={e => setForm({ ...form, nome: e.target.value })} />
                    <input className={campo} placeholder="Telefone com DDD" value={form.telefone} onChange={e => setForm({ ...form, telefone: e.target.value })} />
                    <input className={campo} placeholder="Senha" value={form.senha} onChange={e => setForm({ ...form, senha: e.target.value })} />
                    <input className={campo} placeholder="walletId do Asaas (opcional)" value={form.wallet_id} onChange={e => setForm({ ...form, wallet_id: e.target.value })} />
                </div>
                <button onClick={criar} className="rounded-lg bg-blue-600 hover:bg-blue-500 px-4 py-2 text-sm font-bold text-white">Cadastrar</button>
            </section>

            <section className="space-y-2">
                <h2 className="font-bold text-white">Motoboys ({motoboys.length})</h2>
                {motoboys.length === 0 && <p className="text-sm text-gray-500">Nenhum motoboy cadastrado ainda.</p>}
                {motoboys.map(m => (
                    <div key={m.id} className="flex flex-wrap items-center gap-3 rounded-lg bg-gray-800 p-3 text-sm">
                        <span className={`h-2.5 w-2.5 rounded-full ${noAr(m) ? 'bg-green-400' : 'bg-gray-600'}`} />
                        <span className="font-bold text-white">{m.nome}</span>
                        <span className="text-gray-400">{telefoneBonito(m.telefone)}</span>
                        <span className="text-xs text-gray-500">{noAr(m) ? 'online agora' : 'offline'}{m.wallet_id ? ' | com carteira' : ' | sem carteira'}</span>
                        {!m.ativo && <span className="text-xs text-red-300">desativado</span>}
                        <span className="flex-1" />
                        <button onClick={() => trocarSenha(m)} className="rounded-lg bg-gray-700 px-3 py-1.5 text-xs font-bold text-gray-200">Trocar senha</button>
                        <button onClick={() => alternarAtivo(m)} className="rounded-lg bg-gray-700 px-3 py-1.5 text-xs font-bold text-gray-200">{m.ativo ? 'Desativar' : 'Ativar'}</button>
                    </div>
                ))}
            </section>

            <section className="space-y-2">
                <h2 className="font-bold text-white">Repasses a pagar: {brl(totalPendente)}</h2>
                <p className="text-xs text-gray-500">Faça o PIX para o motoboy e então marque como pago. O frete de cada entrega confirmada entra aqui.</p>
                {motoboys.filter(m => pendentes.some(r => r.motoboy_id === m.id)).map(m => {
                    const meus = pendentes.filter(r => r.motoboy_id === m.id);
                    return (
                        <div key={m.id} className="rounded-lg bg-gray-800 p-3 space-y-2">
                            <div className="flex flex-wrap items-center gap-3 text-sm">
                                <span className="font-bold text-white">{m.nome}</span>
                                <span className="text-orange-300 font-bold">{brl(meus.reduce((s, r) => s + Number(r.valor), 0))}</span>
                                <span className="text-gray-500">{meus.length} entrega(s)</span>
                                <span className="flex-1" />
                                <button onClick={() => pagar(meus.map(r => r.id))} className="rounded-lg bg-green-700 hover:bg-green-600 px-3 py-1.5 text-xs font-bold text-white">Paguei tudo</button>
                            </div>
                            {meus.map(r => (
                                <div key={r.id} className="flex items-center gap-3 text-xs text-gray-400">
                                    <span>{dataHora(r.criado_em)}</span><span className="text-gray-200">{brl(Number(r.valor))}</span><span className="flex-1 truncate">{r.observacao || ''}</span>
                                    <button onClick={() => pagar([r.id])} className="rounded bg-gray-700 px-2 py-1 font-bold text-gray-200">Paguei</button>
                                </div>
                            ))}
                        </div>
                    );
                })}
                {pendentes.length === 0 && <p className="text-sm text-gray-500">Nada a pagar.</p>}
            </section>

            <section className="space-y-2">
                <h2 className="font-bold text-white">Entregas recentes</h2>
                {entregas.length === 0 && <p className="text-sm text-gray-500">Nenhuma entrega ainda.</p>}
                {entregas.map(e => (
                    <div key={e.id} className="flex flex-wrap items-center gap-3 rounded-lg bg-gray-800 p-3 text-sm">
                        <span className="rounded bg-gray-700 px-2 py-0.5 text-xs font-bold text-gray-200">{ROTULO[e.status] || e.status}</span>
                        <span className="text-white">{d.lojaPorId(e.store_id)?.name || 'loja'}</span>
                        <span className="text-gray-400">{brl(Number(e.frete))}</span>
                        <span className="text-gray-500">{nomeMoto(e.motoboy_id)}</span>
                        <span className="text-xs text-gray-600">{dataHora(e.criada_em)}</span>
                        {e.bloqueada && <span className="text-xs text-red-300 font-bold">código bloqueado</span>}
                        {e.motivo && <span className="text-xs text-gray-500">{e.motivo}</span>}
                        <span className="flex-1" />
                        {['prevista', 'disponivel', 'aceita', 'retirada'].includes(e.status) && (
                            <button onClick={() => novoCodigo(e)} className="rounded-lg bg-gray-700 px-3 py-1.5 text-xs font-bold text-gray-200">Código novo</button>
                        )}
                    </div>
                ))}
            </section>
        </div>
    );
};
