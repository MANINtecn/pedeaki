/**
 * Telefone do cliente guardado neste aparelho. Uma chave só, usada pelo Perfil da vitrine e pelas
 * páginas das lojas de comissão, para o cliente digitar o telefone uma vez só.
 * Sem validação (decisão do Ikarus em 05/11/2026): quem digita é quem vale.
 */
export const CHAVE_TELEFONE_CLIENTE = 'pedeaki_cliente_telefone';

export const telefoneDoAparelho = (): string => {
    try { return localStorage.getItem(CHAVE_TELEFONE_CLIENTE) || ''; } catch { return ''; }
};

export const guardarTelefoneDoAparelho = (digitos: string): void => {
    try { localStorage.setItem(CHAVE_TELEFONE_CLIENTE, digitos.replace(/\D/g, '')); } catch { /* sem armazenamento */ }
};

export const apagarTelefoneDoAparelho = (): void => {
    try { localStorage.removeItem(CHAVE_TELEFONE_CLIENTE); } catch { /* tudo bem */ }
};

/** 3299999999 vira (32) 9999-9999; outros tamanhos voltam como vieram. */
export const telefoneBonito = (digitos: string): string => {
    const d = digitos.replace(/\D/g, '');
    if (d.length === 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
    if (d.length === 11) return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
    return digitos;
};
