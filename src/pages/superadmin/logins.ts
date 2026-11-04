import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../../services/supabaseService';

export interface LoginDaPlataforma {
    id: string; email: string; criado_em: string; ultimo_acesso: string | null; administrador: boolean;
    lojas: { id: string; nome: string; slug: string }[];
}

/** Chama a função da Vercel (api/admin-usuarios), que confere se quem chama é administrador da plataforma. */
export async function chamarAdmin(corpo: Record<string, unknown>): Promise<any> {
    const { data } = await supabase.auth.getSession();
    const token = data.session?.access_token;
    if (!token) throw new Error('Sua sessão expirou. Entre de novo no Super Admin.');
    let r: Response;
    try {
        r = await fetch('/api/admin-usuarios', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(corpo) });
    } catch { throw new Error('Sem conexão com o servidor.'); }
    let j: any = null;
    try { j = await r.json(); } catch { /* resposta sem corpo */ }
    if (!r.ok) throw new Error(j?.erro || `Erro ${r.status} (esta função só existe no site publicado na Vercel).`);
    return j;
}

export const gerarSenha = () => {
    const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const bytes = crypto.getRandomValues(new Uint32Array(10));
    return Array.from(bytes, n => letras[n % letras.length]).join('');
};

/** Lista de logins (com as lojas de cada um). Fica vazia, com o motivo em `erro`, se a função da Vercel não responder. */
export function useLogins() {
    const [logins, setLogins] = useState<LoginDaPlataforma[]>([]);
    const [carregando, setCarregando] = useState(true);
    const [erro, setErro] = useState<string | null>(null);
    const recarregar = useCallback(async () => {
        setCarregando(true);
        try {
            const j = await chamarAdmin({ acao: 'listar' });
            setLogins(j.logins || []); setErro(null);
        } catch (e: any) { setErro(e?.message || 'Não foi possível carregar os logins.'); }
        finally { setCarregando(false); }
    }, []);
    useEffect(() => { recarregar(); }, [recarregar]);
    return { logins, carregando, erro, recarregar };
}
