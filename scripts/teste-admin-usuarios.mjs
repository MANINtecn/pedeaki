// Teste da função api/admin-usuarios.js com um Supabase de mentira. Rodar: node scripts/teste-admin-usuarios.mjs
import { tratar } from '../api/admin-usuarios.js';

const LOJA = '11111111-1111-4111-8111-111111111111';
const LOJA2 = '44444444-4444-4444-8444-444444444444';
const ADM_ID = '22222222-2222-4222-8222-222222222222';
const DONO_ID = '33333333-3333-4333-8333-333333333333';
const NOVO_ID = '55555555-5555-4555-8555-555555555555';
const env = { VITE_SUPABASE_URL: 'https://x.supabase.co', VITE_SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'servico' };

function banco(estado = {}) {
    const e = {
        admin: true, servicoValido: true, emailsExistentes: [], chamadas: [], atualizado: null, excluido: null, criado: null,
        usuarios: { [ADM_ID]: 'adm@x.com', [DONO_ID]: 'dono@x.com', [NOVO_ID]: 'novo@x.com' },
        lojas: [
            { id: LOJA, name: 'Madagascar', slug: 'madagascar', owner_id: ADM_ID, owner_email: 'adm@x.com' },
            { id: LOJA2, name: 'Outra', slug: 'outra', owner_id: DONO_ID, owner_email: 'dono@x.com' },
        ],
        ...estado,
    };
    const r = (status, dados) => ({ ok: status < 300, status, text: async () => (typeof dados === 'string' ? dados : JSON.stringify(dados)) });
    const buscar = async (url, o = {}) => {
        const caminho = url.replace(env.VITE_SUPABASE_URL, '');
        const metodo = o.method || 'GET';
        e.chamadas.push(`${metodo} ${caminho}`);
        if (caminho.startsWith('/rest/v1/rpc/is_platform_admin')) return r(200, o.headers.Authorization === 'Bearer jwt-admin' && e.admin ? 'true' : 'false');
        if (o.headers.apikey === 'servico' && !e.servicoValido) return r(401, { message: 'Invalid API key' });
        if (caminho.startsWith('/auth/v1/admin/users?per_page=1000')) return r(200, { users: Object.entries(e.usuarios).map(([id, email]) => ({ id, email, created_at: '2026-11-01', last_sign_in_at: null })) });
        if (caminho.startsWith('/auth/v1/admin/users?per_page')) return r(200, { users: [] });
        if (caminho.startsWith('/rest/v1/platform_admins')) return r(200, [{ email: 'adm@x.com' }]);
        if (caminho.startsWith('/rest/v1/stores?select=')) return r(200, e.lojas);
        if (caminho.startsWith('/rest/v1/stores?id=eq.')) {
            const id = caminho.match(/id=eq\.([^&]+)/)[1];
            const loja = e.lojas.find(l => l.id === id);
            if (metodo === 'GET') return r(200, loja ? [loja] : []);
            if (metodo === 'PATCH') { Object.assign(loja, JSON.parse(o.body)); return r(204, ''); }
        }
        if (caminho.startsWith('/rest/v1/stores?owner_id=eq.') && metodo === 'PATCH') {
            const id = caminho.match(/owner_id=eq\.([^&]+)/)[1];
            e.lojas.filter(l => l.owner_id === id).forEach(l => Object.assign(l, JSON.parse(o.body)));
            return r(204, '');
        }
        if (caminho === '/auth/v1/admin/users' && metodo === 'POST') {
            const b = JSON.parse(o.body);
            if (e.emailsExistentes.includes(b.email)) return r(422, { msg: 'already registered' });
            e.criado = b; return r(200, { id: NOVO_ID, email: b.email });
        }
        if (caminho.startsWith('/auth/v1/admin/users/')) {
            const id = caminho.split('/').pop();
            if (!e.usuarios[id]) return r(404, { msg: 'not found' });
            if (metodo === 'GET') return r(200, { id, email: e.usuarios[id] });
            if (metodo === 'PUT') { e.atualizado = JSON.parse(o.body); return r(200, {}); }
            if (metodo === 'DELETE') { e.excluido = id; return r(200, {}); }
        }
        return r(404, 'nada');
    };
    return { e, buscar };
}

let falhas = 0;
const ok = (nome, cond, extra = '') => { if (!cond) { falhas++; console.log(`FALHA  ${nome} ${extra}`); } else console.log(`ok     ${nome}`); };
const rodar = (b, token, corpo) => tratar({ token, corpo, env, buscar: b.buscar });
const lojaDe = (b, id) => b.e.lojas.find(l => l.id === id);

let b = banco();
let r = await rodar(b, '', { acao: 'teste' });
ok('sem login: 401', r.status === 401);
r = await rodar(b, 'jwt-qualquer', { acao: 'listar' });
ok('quem não é administrador: 403 e nada além da conferência', r.status === 403 && b.e.chamadas.length === 1);
r = await rodar(b, 'jwt-admin', { acao: 'teste' });
ok('teste da chave: aceita', r.status === 200 && r.corpo.chave === 'aceita');
b = banco({ servicoValido: false });
r = await rodar(b, 'jwt-admin', { acao: 'teste' });
ok('teste da chave: recusada', r.status === 502);

b = banco();
r = await rodar(b, 'jwt-admin', { acao: 'listar' });
const dono = r.corpo.logins && r.corpo.logins.find(l => l.id === DONO_ID);
ok('listar: logins com as lojas de cada um', r.status === 200 && r.corpo.logins.length === 3 && dono.lojas[0].slug === 'outra');
ok('listar: marca o administrador', r.corpo.logins.find(l => l.id === ADM_ID).administrador === true && dono.administrador === false);

b = banco();
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'Madagascar@Tecx.pro', senha: '12345678' });
ok('criar login sem loja', r.status === 200 && b.e.criado.email_confirm === true && b.e.criado.email === 'madagascar@tecx.pro' && lojaDe(b, LOJA).owner_id === ADM_ID);
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'novo@tecx.pro', senha: '12345678', store_id: LOJA });
ok('criar login já ligado à loja (pacote)', r.status === 200 && lojaDe(b, LOJA).owner_id === NOVO_ID && lojaDe(b, LOJA).owner_email === 'novo@tecx.pro');
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'abc', senha: '12345678' });
ok('criar: e-mail inválido', r.status === 400);
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'a@b.co', senha: '123' });
ok('criar: senha curta', r.status === 400);
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'adm@x.com', senha: '12345678' });
ok('criar: e-mail de administrador recusado', r.status === 409);
b = banco({ emailsExistentes: ['ja@x.com'] });
r = await rodar(b, 'jwt-admin', { acao: 'criar', email: 'ja@x.com', senha: '12345678', store_id: LOJA });
ok('criar: e-mail já existente não mexe na loja', r.status === 409 && lojaDe(b, LOJA).owner_id === ADM_ID);

b = banco();
r = await rodar(b, 'jwt-admin', { acao: 'vincular', store_id: LOJA, user_id: DONO_ID });
ok('vincular: escolhe o login e troca o dono da loja', r.status === 200 && lojaDe(b, LOJA).owner_id === DONO_ID && lojaDe(b, LOJA).owner_email === 'dono@x.com');
r = await rodar(b, 'jwt-admin', { acao: 'vincular', store_id: LOJA, user_id: '66666666-6666-4666-8666-666666666666' });
ok('vincular: login inexistente', r.status === 404);
r = await rodar(b, 'jwt-admin', { acao: 'desvincular', store_id: LOJA });
ok('desvincular: loja fica sem dono e o login continua', r.status === 200 && lojaDe(b, LOJA).owner_id === null && !b.e.excluido);

b = banco();
r = await rodar(b, 'jwt-admin', { acao: 'senha', user_id: DONO_ID, senha: 'novaSenha1' });
ok('senha: troca', r.status === 200 && b.e.atualizado.password === 'novaSenha1');
r = await rodar(b, 'jwt-admin', { acao: 'senha', user_id: DONO_ID, senha: 'curta' });
ok('senha curta recusada', r.status === 400);
r = await rodar(b, 'jwt-admin', { acao: 'email', user_id: DONO_ID, email: 'novo@dono.com' });
ok('e-mail: troca e acompanha as lojas dele', r.status === 200 && b.e.atualizado.email === 'novo@dono.com' && lojaDe(b, LOJA2).owner_email === 'novo@dono.com');
b = banco();
r = await rodar(b, 'jwt-admin', { acao: 'excluir', user_id: DONO_ID });
ok('excluir login: apaga o login e a loja continua, sem dono', r.status === 200 && b.e.excluido === DONO_ID && lojaDe(b, LOJA2).owner_id === null && !!lojaDe(b, LOJA2));

b = banco();
for (const acao of ['senha', 'email', 'excluir']) {
    r = await rodar(b, 'jwt-admin', { acao, user_id: ADM_ID, senha: 'novaSenha1', email: 'n@x.com' });
    ok(`login de administrador protegido (${acao})`, r.status === 409 && !b.e.atualizado && !b.e.excluido && lojaDe(b, LOJA).owner_id === ADM_ID);
}
r = await rodar(b, 'jwt-admin', { acao: 'vincular', store_id: 'nao-uuid', user_id: DONO_ID });
ok('loja inválida', r.status === 400);

console.log(falhas ? `\n${falhas} FALHA(S)` : '\nTudo certo.');
process.exit(falhas ? 1 : 0);
