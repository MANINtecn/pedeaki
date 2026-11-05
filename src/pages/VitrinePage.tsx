import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import {
    MapPin, Search, UtensilsCrossed, Leaf, Pill, Wine, Tractor, Armchair, Gift, PartyPopper,
    Plus, Home, ShoppingCart, User, ArrowRight, Megaphone,
} from 'lucide-react';
import { fetchLojasShopping, type LojaShopping } from '../services/supabaseService';

// Nova home do shopping (desenho aprovado na rodada 4). Rota /vitrine, separada da /shopping atual.
// Só mostra o que existe no banco: nome, logo, categoria e cidade da loja. Dono, tempo, taxa e
// patrocínio ainda não existem como dado, por isso não aparecem aqui (nada de preço inventado).

const CIDADE_FIXA = 'Tocantins, MG'; // até a cidade automática por localização existir

const semAcento = (t: string) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

const corte = (px: number): React.CSSProperties => ({
    clipPath: `polygon(${px}px 0%, calc(100% - ${px}px) 0%, 100% ${px}px, 100% calc(100% - ${px}px), calc(100% - ${px}px) 100%, ${px}px 100%, 0% calc(100% - ${px}px), 0% ${px}px)`,
});

const CATEGORIAS_EM_BREVE = [
    { nome: 'Hortifruti', cor: '#5FD068', Icone: Leaf },
    { nome: 'Farmácia', cor: '#2FC4B2', Icone: Pill },
    { nome: 'Bebidas', cor: '#4DA3FF', Icone: Wine },
    { nome: 'Agro', cor: '#A3D133', Icone: Tractor },
    { nome: 'Utilidades', cor: '#B07CFF', Icone: Armchair },
    { nome: 'Presentes', cor: '#F0649C', Icone: Gift },
    { nome: 'Eventos', cor: '#FF7A59', Icone: PartyPopper },
];

const Imagem: React.FC<{ loja: LojaShopping; className?: string }> = ({ loja, className = '' }) => {
    const [falhou, setFalhou] = useState(false);
    if (loja.logo_url && !falhou) {
        return <img src={loja.logo_url} alt="" loading="lazy" decoding="async" onError={() => setFalhou(true)} className={`w-full h-full object-cover ${className}`} />;
    }
    return (
        <div className="w-full h-full flex items-center justify-center font-black text-3xl text-black bg-gradient-to-br from-[#FF6A1A] to-[#FF9A5A]">
            {loja.name.trim().charAt(0).toUpperCase()}
        </div>
    );
};

const VitrinePage: React.FC = () => {
    const [lojas, setLojas] = useState<LojaShopping[] | null>(null);
    const [texto, setTexto] = useState('');
    const faixa = useRef<HTMLDivElement>(null);
    const campo = useRef<HTMLInputElement>(null);
    const lista = useRef<HTMLElement>(null);
    const [pos, setPos] = useState(0);

    // Fontes só desta página
    useEffect(() => {
        const l = document.createElement('link');
        l.rel = 'stylesheet';
        l.href = 'https://fonts.googleapis.com/css2?family=Anton&family=Space+Grotesk:wght@400;500;600;700&display=swap';
        document.head.appendChild(l);
        return () => { document.head.removeChild(l); };
    }, []);

    useEffect(() => { fetchLojasShopping().then(setLojas).catch(() => setLojas([])); }, []);

    const termo = semAcento(texto.trim());
    const visiveis = useMemo(
        () => (lojas || []).filter(l => !termo || semAcento(`${l.name} ${l.categoria || ''}`).includes(termo)),
        [lojas, termo],
    );
    const destaques = useMemo(() => (lojas || []).slice(0, 2), [lojas]);

    // Rotação do banner: 5 s, para por 12 s quando o dedo toca
    const pausaAte = useRef(0);
    useEffect(() => {
        const el = faixa.current;
        if (!el || destaques.length < 2) return;
        if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
        const id = setInterval(() => {
            if (Date.now() < pausaAte.current) return;
            const filho = el.firstElementChild as HTMLElement | null;
            if (!filho) return;
            const passo = filho.offsetWidth + 12;
            const prox = (Math.round(el.scrollLeft / passo) + 1) % destaques.length;
            el.scrollTo({ left: prox * passo, behavior: 'smooth' });
        }, 5000);
        return () => clearInterval(id);
    }, [destaques.length]);

    const aoRolar = () => {
        const el = faixa.current;
        const filho = el?.firstElementChild as HTMLElement | null;
        if (!el || !filho) return;
        setPos(Math.min(destaques.length - 1, Math.round(el.scrollLeft / (filho.offsetWidth + 12))));
    };

    const irParaLojas = () => lista.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    const irParaBusca = () => { window.scrollTo({ top: 0, behavior: 'smooth' }); campo.current?.focus(); };

    const titulo = (t: string) => (
        <div className="flex items-center gap-2 px-4">
            <span className="w-2.5 h-2.5 bg-[#FF6A1A] rotate-45 shadow-[0_0_6px_#FF6A1A]" />
            <h2 style={{ fontFamily: 'Anton, sans-serif' }} className="text-[26px] tracking-wide uppercase leading-none">{t}</h2>
        </div>
    );

    return (
        <div className="min-h-screen flex justify-center bg-[#0B0910]" style={{ fontFamily: '"Space Grotesk", sans-serif' }}>
            <div className="w-full max-w-[390px] min-h-screen bg-[#110E15] text-[#F7EFE4] border-x border-[#241F2B] flex flex-col pb-24 overflow-x-hidden">

                {/* Topo */}
                <header className="sticky top-0 z-40 bg-[#110E15]/95 backdrop-blur-md px-4 pt-3 pb-3 border-b border-[#241F2B]">
                    <div className="flex items-center justify-between gap-2 mb-3">
                        <div style={corte(6)} className="flex items-center gap-1.5 py-1 px-2.5 bg-[#1A171F] border border-[#322C3A]">
                            <MapPin size={16} className="text-[#FF6A1A]" />
                            <span className="text-[13px] font-bold">{CIDADE_FIXA}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-1.5 h-4 bg-[#FF6A1A] shadow-[0_0_8px_#FF6A1A]" />
                            <span style={{ fontFamily: 'Anton, sans-serif', textShadow: '0 0 12px rgba(255,106,26,.7)' }} className="text-[24px] tracking-wider uppercase">PEDE AKI</span>
                        </div>
                    </div>
                    <label style={corte(6)} className="flex items-center bg-[#3E3647] border border-[#5A506A] focus-within:border-[#FF6A1A]">
                        <Search size={18} className="ml-3 shrink-0" />
                        <input
                            ref={campo}
                            value={texto}
                            onChange={e => setTexto(e.target.value)}
                            type="search"
                            placeholder="Buscar loja no shopping..."
                            className="w-full bg-transparent py-2 px-2.5 text-[13px] placeholder:text-[#CFC7D6] border-none outline-none focus:ring-0"
                        />
                    </label>
                </header>

                <main className="flex flex-col gap-6 pt-3">

                    {/* Categorias */}
                    <section className="flex flex-col gap-2.5">
                        {titulo('O QUE VOCÊ QUER HOJE?')}
                        <div className="grid grid-cols-4 gap-2 px-4">
                            <button onClick={irParaLojas} style={{ ...corte(10), boxShadow: '0 0 12px -2px rgba(255,106,26,.4)' }}
                                className="relative bg-[#1A171F] py-2.5 px-1 border border-[#FF6A1A] flex flex-col items-center gap-1 active:scale-[0.97]">
                                <span className="absolute top-1 right-2 w-1.5 h-1.5 rounded-full bg-[#FF6A1A] animate-pulse" />
                                <UtensilsCrossed size={22} className="text-[#FF6A1A]" />
                                <span style={{ fontFamily: 'Anton, sans-serif' }} className="text-[13px] tracking-wide uppercase leading-none">Comer</span>
                                <span className="text-[8px] font-bold uppercase tracking-wider text-[#FF6A1A]">{lojas ? `${lojas.length} ${lojas.length === 1 ? 'loja' : 'lojas'}` : '...'}</span>
                            </button>
                            {CATEGORIAS_EM_BREVE.map(({ nome, cor, Icone }) => (
                                <div key={nome} style={{ ...corte(10), borderColor: `${cor}73` }}
                                    className="bg-[#2A2430] py-2.5 px-1 border flex flex-col items-center gap-1">
                                    <Icone size={22} style={{ color: cor }} />
                                    <span style={{ fontFamily: 'Anton, sans-serif' }} className="text-[13px] tracking-wide uppercase leading-none">{nome}</span>
                                    <span className="text-[8px] font-bold uppercase tracking-wider text-[#C9C1D1]">Em breve</span>
                                </div>
                            ))}
                        </div>
                        <Link to="/cadastro" className="self-start px-4 text-[11px] font-bold uppercase tracking-wider text-[#C9C1D1] flex items-center gap-1">
                            <Plus size={14} className="text-[#FF6A1A]" />Falta uma categoria? Indique uma loja
                        </Link>
                    </section>

                    {/* Em destaque, nível 1: banner rotativo */}
                    {destaques.length > 0 && !termo && (
                        <section className="flex flex-col gap-2.5">
                            {titulo('EM DESTAQUE')}
                            <div ref={faixa} onScroll={aoRolar}
                                onTouchStart={() => { pausaAte.current = Date.now() + 12000; }}
                                onWheel={() => { pausaAte.current = Date.now() + 12000; }}
                                className="flex gap-3 overflow-x-auto snap-x snap-mandatory px-4" style={{ scrollbarWidth: 'none' }}>
                                {destaques.map(l => (
                                    <Link key={l.id} to={`/${l.slug}`} style={corte(14)}
                                        className="snap-start shrink-0 w-[88%] bg-[#F7EFE4] text-[#15121A] p-2 flex gap-2.5 border-2 border-[#F7EFE4]">
                                        <div style={corte(10)} className="relative w-[104px] h-[104px] shrink-0 overflow-hidden bg-black">
                                            <Imagem loja={l} />
                                            <span style={corte(4)} className="absolute top-1.5 left-1.5 px-1.5 py-0.5 bg-[#FF6A1A] text-black text-[8px] font-bold uppercase tracking-wider">Patrocinado</span>
                                            <div className="absolute bottom-0 left-0 right-0 h-1 bg-[#FF6A1A]" />
                                        </div>
                                        <div className="min-w-0 flex-1 flex flex-col justify-between py-0.5">
                                            <div>
                                                <h3 style={{ fontFamily: 'Anton, sans-serif' }} className="text-[17px] tracking-wide uppercase leading-none truncate">{l.name}</h3>
                                                <p className="text-[11px] text-[#6B6C72] mt-1">{[l.categoria, l.cidade].filter(Boolean).join(' • ')}</p>
                                            </div>
                                            <span style={{ ...corte(8), fontFamily: 'Anton, sans-serif' }} className="self-end px-3 py-1.5 bg-[#FF6A1A] text-black text-[13px] tracking-wider uppercase flex items-center gap-1">Ver cardápio <ArrowRight size={14} /></span>
                                        </div>
                                    </Link>
                                ))}
                            </div>
                            {destaques.length > 1 && (
                                <div className="flex justify-center gap-1.5">
                                    {destaques.map((l, i) => <span key={l.id} className={`h-1 ${i === pos ? 'w-5 bg-[#FF6A1A]' : 'w-2 bg-[#3E3647]'}`} />)}
                                </div>
                            )}

                            {/* nível 2: faixa de selos */}
                            <span className="px-4 pt-1 text-[10px] font-bold uppercase tracking-widest text-[#CFC7D6]">Lojas patrocinadas</span>
                            <div className="flex gap-3 overflow-x-auto px-4 pb-1" style={{ scrollbarWidth: 'none' }}>
                                {destaques.map(l => (
                                    <Link key={l.id} to={`/${l.slug}`} className="shrink-0 w-[68px] flex flex-col items-center gap-1 active:scale-[0.97]">
                                        <span style={corte(10)} className="block bg-[#FF6A1A] p-[2px]">
                                            <span style={corte(8)} className="block w-[64px] h-[64px] overflow-hidden bg-black"><Imagem loja={l} /></span>
                                        </span>
                                        <span className="text-[10px] font-bold leading-tight text-center">{l.name}</span>
                                    </Link>
                                ))}
                                {[0, 1, 2].map(i => (
                                    <Link key={i} to="/cadastro" className="shrink-0 w-[68px] flex flex-col items-center gap-1 active:scale-[0.97]">
                                        <span style={corte(10)} className="flex items-center justify-center w-[68px] h-[68px] border border-dashed border-[#5A506A] text-[#FF6A1A] bg-[#1A171F]"><Plus size={24} /></span>
                                        <span className="text-[10px] font-bold leading-tight text-center text-[#CFC7D6]">Sua loja aqui</span>
                                    </Link>
                                ))}
                            </div>
                        </section>
                    )}

                    {/* Lojas */}
                    <section ref={lista} className="flex flex-col gap-3.5 scroll-mt-28">
                        {titulo(termo ? 'RESULTADO' : 'ABERTOS AGORA')}
                        <div className="flex flex-col gap-3.5 px-4">
                            {lojas === null && <p className="text-[13px] text-[#CFC7D6]">Carregando as lojas da cidade...</p>}
                            {lojas !== null && visiveis.length === 0 && (
                                <p className="text-[13px] text-[#CFC7D6]">{termo ? 'Nenhuma loja com esse nome.' : 'Ainda não chegamos aqui. Em breve as primeiras lojas.'}</p>
                            )}
                            {visiveis.map(l => (
                                <Link key={l.id} to={`/${l.slug}`} style={corte(14)} className="bg-[#F7EFE4] text-[#15121A] p-3 flex gap-3 border-2 border-[#F7EFE4] active:scale-[0.99]">
                                    <div style={corte(10)} className="relative w-24 h-24 shrink-0 overflow-hidden bg-black">
                                        <Imagem loja={l} />
                                        <div className="absolute bottom-0 left-0 right-0 h-1 bg-[#FF6A1A]" />
                                    </div>
                                    <div className="min-w-0 flex-1 flex flex-col justify-between">
                                        <div>
                                            <h3 style={{ fontFamily: 'Anton, sans-serif' }} className="text-[22px] tracking-wide uppercase leading-none">{l.name}</h3>
                                            <p className="text-[12px] text-[#55565B] mt-1">{[l.categoria, l.cidade].filter(Boolean).join(' • ')}</p>
                                        </div>
                                        <span style={{ ...corte(8), fontFamily: 'Anton, sans-serif' }} className="self-start px-3 py-1.5 bg-[#FF6A1A] text-black text-[13px] tracking-wider uppercase flex items-center gap-1">Ver cardápio <ArrowRight size={14} /></span>
                                    </div>
                                </Link>
                            ))}
                        </div>
                    </section>

                    {/* Convite ao lojista */}
                    <section className="px-4">
                        <div style={corte(10)} className="bg-[#1A171F] border border-[#322C3A] p-4 flex flex-col gap-2.5">
                            <div className="flex items-center gap-2 text-[#FF6A1A]">
                                <Megaphone size={18} />
                                <span className="text-[11px] font-bold uppercase tracking-widest">Comércio de {CIDADE_FIXA}</span>
                            </div>
                            <h4 style={{ fontFamily: 'Anton, sans-serif' }} className="text-[22px] tracking-wide uppercase leading-tight">QUER VER SUA LOJA AQUI?</h4>
                            <p className="text-[12px] text-[#B9B0C2] leading-relaxed">Coloque sua vitrine digital no ar sem burocracia e atenda os clientes da nossa cidade.</p>
                            <Link to="/cadastro" style={corte(8)} className="mt-1 py-2 px-3 bg-[#1D1923] border border-[#FF6A1A]/50 text-center font-bold text-[12px] tracking-wider uppercase">Cadastrar meu negócio</Link>
                        </div>
                    </section>
                </main>

                {/* Navegação */}
                <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[390px] z-50 bg-[#15121A] border-t border-[#241F2B] px-2 py-1 flex items-center justify-around" style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}>
                    <button onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })} className="flex flex-col items-center py-1 text-[#FF6A1A] font-bold"><Home size={20} /><span className="text-[10px] tracking-wider mt-0.5">Início</span></button>
                    <button onClick={irParaBusca} className="flex flex-col items-center py-1 text-[#B9B0C2] font-medium"><Search size={20} /><span className="text-[10px] tracking-wider mt-0.5">Busca</span></button>
                    <span className="flex flex-col items-center py-1 text-[#B9B0C2]/40 font-medium" title="O carrinho do shopping vem depois"><ShoppingCart size={20} /><span className="text-[10px] tracking-wider mt-0.5">Carrinho</span></span>
                    <Link to="/entrar" className="flex flex-col items-center py-1 text-[#B9B0C2] font-medium"><User size={20} /><span className="text-[10px] tracking-wider mt-0.5">Perfil</span></Link>
                </nav>
            </div>
        </div>
    );
};

export default VitrinePage;
