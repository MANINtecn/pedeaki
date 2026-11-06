/**
 * "Aberta agora" da vitrine. Mesma regra da página da loja (useStoreStatus): status manual manda,
 * depois os dias de funcionamento, depois o horário (o do dia da semana, se houver, senão o padrão),
 * com virada de meia-noite. Usa a hora do aparelho do cliente.
 * Diferença de propósito: lista de dias vazia vale como "sem restrição" (a página da loja a trataria
 * como fechada), para uma configuração em branco não esconder a loja.
 */
export interface InfoLojaShopping {
    store_id: string;
    manual_status: string | null;
    days_of_week: unknown;
    opening_time: string | null;
    closing_time: string | null;
    custom_hours: unknown;
    tempo_tipico_min: number | null;
    amostra: number;
}

export interface StatusDaLoja {
    /** true aberta, false fechada, null não dá para saber (sem horário cadastrado). */
    aberta: boolean | null;
    /** Texto curto: "Fecha às 23:30", "Abre às 18:00", "Não abre hoje", "Fechada no momento". */
    detalhe: string;
}

const hhmm = (t: string) => t.slice(0, 5);
const emHoras = (t: string) => { const [h, m] = t.split(':').map(Number); return h + (m || 0) / 60; };

export function statusDaLoja(info: InfoLojaShopping | undefined, agora: Date = new Date()): StatusDaLoja {
    if (!info) return { aberta: null, detalhe: '' };
    if (info.manual_status === 'closed') return { aberta: false, detalhe: 'Fechada no momento' };
    if (info.manual_status === 'open') return { aberta: true, detalhe: '' };

    const dia = agora.getDay();
    const hora = agora.getHours() + agora.getMinutes() / 60;

    const dias = Array.isArray(info.days_of_week) ? (info.days_of_week as unknown[]).map(String) : [];
    if (dias.length > 0 && !dias.includes(String(dia))) return { aberta: false, detalhe: 'Não abre hoje' };

    const personalizado = (info.custom_hours && typeof info.custom_hours === 'object')
        ? (info.custom_hours as Record<string, { open?: string; close?: string }>)[String(dia)]
        : undefined;
    const abre = personalizado?.open || info.opening_time;
    const fecha = personalizado?.close || info.closing_time;
    if (!abre || !fecha) return { aberta: null, detalhe: '' };

    const ini = emHoras(abre);
    const fim = emHoras(fecha);
    const aberta = fim < ini ? (hora >= ini || hora < fim) : (hora >= ini && hora < fim);
    return aberta
        ? { aberta: true, detalhe: `Fecha às ${hhmm(fecha)}` }
        : { aberta: false, detalhe: hora < ini ? `Abre às ${hhmm(abre)}` : 'Fechada no momento' };
}
