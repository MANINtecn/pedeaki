/**
 * Logins dos donos de loja, feitos pelo painel do Super Admin. Função serverless da Vercel.
 *
 * Quem chama: o painel (Super Admin), com o login do administrador no cabeçalho Authorization.
 * O que faz: login é uma coisa e loja é outra. Cria logins já confirmados (sem e-mail de confirmação), lista,
 * troca senha e e-mail, exclui, e liga ou solta uma loja de um login. Exige a chave de serviço, que só existe aqui.
 *
 * Segurança: antes de qualquer ação, pergunta ao banco (função is_platform_admin, com o login de quem chamou)
 * se é administrador da plataforma. Sem isso nada acontece. Contas de administrador nunca são alteradas por aqui.
 *
 * Variáveis na Vercel: SUPABASE_SERVICE_ROLE_KEY (a chave de serviço, no formato sb_secret_... ou JWT antigo,
 * nunca a sb_publishable) e as que o site já usa (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY).
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const erro = (status, mensagem) => ({ status, corpo: { erro: mensagem } });

/** Núcleo sem dependência de ambiente (para testar com dados falsos). Devolve { status, corpo }. */
export async function tratar({ token, corpo, env, buscar }) {
    const base = env.SUPABASE_URL || env.VITE_SUPABASE_URL;
    const anon = env.SUPABASE_ANON_KEY || env.VITE_SUPABASE_ANON_KEY;
    // Tira espaços, quebras de linha e aspas que costumam vir junto ao colar a chave na Vercel.
    const servico = String(env.SUPABASE_SERVICE_ROLE_KEY || '').trim().replace(/^["']|["']$/g, '').trim();
    if (!base || !anon) return erro(500, 'Supabase não configurado na Vercel');
    if (!token) return erro(401, 'negado');

    // 1. Quem chamou é administrador? (o banco responde com o login dele)
    let admin = false;
    try {
        const r = await buscar(`${base}/rest/v1/rpc/is_platform_admin`, {
            method: 'POST',
            headers: { apikey: anon, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
            body: '{}',
        });
        admin = r.ok && (await r.text()).trim() === 'true';
    } catch (_) { admin = false; }
    if (!admin) return erro(403, 'negado');

    if (!servico) return erro(500, 'SUPABASE_SERVICE_ROLE_KEY não está configurada na Vercel');
    // Chave antiga (JWT, tem 3 partes separadas por ponto) vai nos dois cabeçalhos. Chave nova (sb_secret_...)
    // não é JWT: o Supabase só aceita no cabeçalho apikey e recusa se ela vier em Authorization.
    const chaveEhJwt = servico.split('.').length === 3;
    /** Descreve a chave sem mostrá-la: só o formato, o tamanho e o começo do prefixo. Ajuda a achar chave errada. */
    const descreverChave = () => {
        const tipo = servico.startsWith('sb_secret_') ? 'sb_secret' : servico.startsWith('sb_publishable_') ? 'sb_publishable (chave pública, não serve)' : chaveEhJwt ? 'JWT antigo' : 'formato desconhecido';
        return `tipo ${tipo}, ${servico.length} caracteres`;
    };
    const cab = { apikey: servico, ...(chaveEhJwt ? { Authorization: `Bearer ${servico}` } : {}), 'Content-Type': 'application/json' };
    const chamar = async (caminho, opc = {}) => {
        const r = await buscar(`${base}${caminho}`, { ...opc, headers: { ...cab, ...(opc.headers || {}) } });
        const t = await r.text();
        let dados = null;
        try { dados = t ? JSON.parse(t) : null; } catch (_) { dados = t; }
        return { ok: r.ok, status: r.status, dados };
    };
    const msg = (r) => String((r.dados && (r.dados.msg || r.dados.message || r.dados.error_description || r.dados.error)) || `erro ${r.status}`).slice(0, 160);

    const acao = corpo && corpo.acao;

    // Teste da chave: não mexe em nada.
    if (acao === 'teste') {
        const r = await chamar('/auth/v1/admin/users?per_page=1');
        return r.ok ? { status: 200, corpo: { ok: true, chave: 'aceita' } } : erro(502, `chave de serviço recusada pelo Supabase (${r.status}: ${msg(r)}). A chave recebida: ${descreverChave()}.`);
    }

    /** Conta de administrador nunca é alterada por esta tela. */
    const eAdministrador = async (email) => {
        const r = await chamar('/rest/v1/platform_admins?select=email');
        return r.ok && Array.isArray(r.dados) && r.dados.some(a => String(a.email || '').toLowerCase() === String(email || '').toLowerCase());
    };
    const buscarUsuario = async (id) => {
        if (!id || !UUID.test(id)) return { erro: erro(400, 'login inválido') };
        const u = await chamar(`/auth/v1/admin/users/${id}`);
        if (u.status === 401 || u.status === 403) return { erro: erro(502, `o Supabase recusou a chave de serviço: ${msg(u)} (chave recebida: ${descreverChave()})`) };
        if (!u.ok || !u.dados || !u.dados.id) return { erro: erro(404, 'login não encontrado') };
        return { usuario: u.dados };
    };
    const buscarLoja = async (id) => {
        if (!id || !UUID.test(id)) return { erro: erro(400, 'loja inválida') };
        const l = await chamar(`/rest/v1/stores?id=eq.${id}&select=id,slug,owner_id,owner_email`);
        if (!l.ok || !Array.isArray(l.dados) || !l.dados[0]) return { erro: erro(404, 'loja não encontrada') };
        return { loja: l.dados[0] };
    };
    const ligar = (storeId, dados) => chamar(`/rest/v1/stores?id=eq.${storeId}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(dados) });

    // Lista de logins, cada um com as lojas ligadas a ele.
    if (acao === 'listar') {
        const [us, ls, ad] = await Promise.all([
            chamar('/auth/v1/admin/users?per_page=1000'),
            chamar('/rest/v1/stores?select=id,name,slug,owner_id'),
            chamar('/rest/v1/platform_admins?select=email'),
        ]);
        if (!us.ok) return erro(502, `não foi possível listar os logins: ${msg(us)} (chave recebida: ${descreverChave()})`);
        const admins = new Set((Array.isArray(ad.dados) ? ad.dados : []).map(a => String(a.email || '').toLowerCase()));
        const lojas = Array.isArray(ls.dados) ? ls.dados : [];
        const logins = ((us.dados && us.dados.users) || []).map(u => ({
            id: u.id, email: u.email, criado_em: u.created_at, ultimo_acesso: u.last_sign_in_at || null,
            administrador: admins.has(String(u.email || '').toLowerCase()),
            lojas: lojas.filter(l => l.owner_id === u.id).map(l => ({ id: l.id, nome: l.name, slug: l.slug })),
        })).sort((a, b) => String(a.email).localeCompare(String(b.email)));
        return { status: 200, corpo: { ok: true, logins } };
    }

    // Cria só o login (sem loja). Com store_id, já liga à loja: é o "pacote" de criar loja e login juntos.
    if (acao === 'criar') {
        const email = String(corpo.email || '').trim().toLowerCase();
        const senha = String(corpo.senha || '');
        if (!EMAIL.test(email)) return erro(400, 'e-mail inválido');
        if (senha.length < 8) return erro(400, 'a senha precisa ter pelo menos 8 caracteres');
        let loja = null;
        if (corpo.store_id) { const b = await buscarLoja(corpo.store_id); if (b.erro) return b.erro; loja = b.loja; }
        if (await eAdministrador(email)) return erro(409, 'este e-mail é de administrador da plataforma');
        const c = await chamar('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, password: senha, email_confirm: true }) });
        if (!c.ok) return erro(c.status === 422 ? 409 : 502, c.status === 422 ? 'já existe um login com este e-mail' : `não foi possível criar: ${msg(c)}`);
        if (loja) {
            const p = await ligar(loja.id, { owner_id: c.dados.id, owner_email: email });
            if (!p.ok) return erro(502, `login criado, mas não foi ligado à loja: ${msg(p)}`);
        }
        return { status: 200, corpo: { ok: true, user_id: c.dados.id, email } };
    }

    if (acao === 'senha') {
        const senha = String(corpo.senha || '');
        if (senha.length < 8) return erro(400, 'a senha precisa ter pelo menos 8 caracteres');
        const b = await buscarUsuario(corpo.user_id); if (b.erro) return b.erro;
        if (await eAdministrador(b.usuario.email)) return erro(409, 'este login é de administrador da plataforma: não é alterado por aqui');
        const r = await chamar(`/auth/v1/admin/users/${b.usuario.id}`, { method: 'PUT', body: JSON.stringify({ password: senha }) });
        return r.ok ? { status: 200, corpo: { ok: true, email: b.usuario.email } } : erro(502, `não foi possível trocar a senha: ${msg(r)}`);
    }

    if (acao === 'email') {
        const email = String(corpo.email || '').trim().toLowerCase();
        if (!EMAIL.test(email)) return erro(400, 'e-mail inválido');
        if (await eAdministrador(email)) return erro(409, 'este e-mail é de administrador da plataforma');
        const b = await buscarUsuario(corpo.user_id); if (b.erro) return b.erro;
        if (await eAdministrador(b.usuario.email)) return erro(409, 'este login é de administrador da plataforma: não é alterado por aqui');
        const r = await chamar(`/auth/v1/admin/users/${b.usuario.id}`, { method: 'PUT', body: JSON.stringify({ email, email_confirm: true }) });
        if (!r.ok) return erro(r.status === 422 ? 409 : 502, r.status === 422 ? 'já existe um login com este e-mail' : `não foi possível trocar o e-mail: ${msg(r)}`);
        await chamar(`/rest/v1/stores?owner_id=eq.${b.usuario.id}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ owner_email: email }) });
        return { status: 200, corpo: { ok: true, email } };
    }

    // Exclui o login. As lojas dele ficam sem dono (continuam existindo, prontas para outro login).
    if (acao === 'excluir') {
        const b = await buscarUsuario(corpo.user_id); if (b.erro) return b.erro;
        if (await eAdministrador(b.usuario.email)) return erro(409, 'este login é de administrador da plataforma: não é excluído por aqui');
        const p = await chamar(`/rest/v1/stores?owner_id=eq.${b.usuario.id}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ owner_id: null }) });
        if (!p.ok) return erro(502, `não foi possível soltar as lojas deste login: ${msg(p)}`);
        const r = await chamar(`/auth/v1/admin/users/${b.usuario.id}`, { method: 'DELETE' });
        return r.ok ? { status: 200, corpo: { ok: true } } : erro(502, `lojas soltas, mas o login não foi excluído: ${msg(r)}`);
    }

    // Liga uma loja a um login que já existe (escolhido na lista). Troca o dono anterior.
    if (acao === 'vincular') {
        const l = await buscarLoja(corpo.store_id); if (l.erro) return l.erro;
        const b = await buscarUsuario(corpo.user_id); if (b.erro) return b.erro;
        const p = await ligar(l.loja.id, { owner_id: b.usuario.id, owner_email: String(b.usuario.email || '').toLowerCase() });
        return p.ok ? { status: 200, corpo: { ok: true } } : erro(502, `não foi possível ligar: ${msg(p)}`);
    }

    // Solta a loja do login atual (o login continua existindo).
    if (acao === 'desvincular') {
        const l = await buscarLoja(corpo.store_id); if (l.erro) return l.erro;
        const p = await ligar(l.loja.id, { owner_id: null });
        return p.ok ? { status: 200, corpo: { ok: true } } : erro(502, `não foi possível desvincular: ${msg(p)}`);
    }

    return erro(400, 'ação desconhecida');
}

export default async function handler(req, res) {
    if (req.method !== 'POST') return res.status(405).json({ erro: 'metodo' });
    let corpo = req.body;
    if (typeof corpo === 'string') { try { corpo = JSON.parse(corpo); } catch (_) { corpo = null; } }
    const auth = String(req.headers.authorization || '');
    const token = auth.toLowerCase().startsWith('bearer ') ? auth.slice(7).trim() : '';
    try {
        const r = await tratar({ token, corpo, env: process.env, buscar: fetch });
        return res.status(r.status).json(r.corpo);
    } catch (e) {
        return res.status(500).json({ erro: String((e && e.message) || e).slice(0, 200) });
    }
}
