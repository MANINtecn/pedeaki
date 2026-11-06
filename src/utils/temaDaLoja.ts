/**
 * Tema (paleta) das lojas de comissão, por categoria da loja. O layout é o mesmo do Pede Aki; só
 * mudam as cores. Comida é o tema padrão (hoje só existe o corredor Comer). As paletas estão em
 * index.css como html.tema-pedeaki.pa-<tema>.
 */
export type TemaLoja = 'comer' | 'hortifruti' | 'farmacia' | 'agro' | 'presentes' | 'eventos' | 'utilidades';

const semAcento = (t: string) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

const REGRAS: Array<[TemaLoja, string[]]> = [
    ['hortifruti', ['horti', 'fruta', 'verdura', 'legume', 'sacolao', 'quitanda']],
    ['farmacia', ['farmac', 'saude', 'droga', 'drogaria', 'bem-estar', 'bem estar']],
    ['agro', ['agro', 'racao', 'veterin', 'insumo', 'rural', 'pet']],
    ['presentes', ['presente', 'floricultura', 'flor', 'cesta', 'brinde']],
    ['eventos', ['evento', 'festa', 'ingresso', 'show']],
    ['utilidades', ['utilidade', 'casa', 'material', 'variedade', 'papelaria', 'moda', 'loja de']],
];

export function temaDaCategoria(categoria?: string | null): TemaLoja {
    const c = semAcento(categoria || '');
    if (!c) return 'comer';
    for (const [tema, palavras] of REGRAS) {
        if (palavras.some(p => c.includes(p))) return tema;
    }
    return 'comer'; // Lanchonete, Sorveteria, Pizzaria, Restaurante, Padaria, Outros...
}
