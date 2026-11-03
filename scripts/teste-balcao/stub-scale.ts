// Balança falsa. Por padrão fica muda (desconectada) -- os testes antigos não mudam.
// 19/10/2026: controlável pelo teste via globalThis.__balanca.set(kg, estavel) -> manda o
// snapshot para o CounterTab exatamente como o stream real da Urano (subscribeToScale).
const g: any = globalThis;
let snap: any = { weightKg: 0, isStable: false, status: "disconnected", lastRaw: "" };
const ouvintes = new Set<(s: any) => void>();
g.__balanca = {
  set(kg: number, estavel = true) {
    snap = { weightKg: kg, isStable: estavel, status: estavel ? "stable" : "unstable", lastRaw: `${estavel ? "ST" : "US"},GS,${kg.toFixed(3)}kg` };
    ouvintes.forEach(f => f({ ...snap }));
  },
  desconectar() { snap = { weightKg: 0, isStable: false, status: "disconnected", lastRaw: "" }; ouvintes.forEach(f => f({ ...snap })); },
  get atual() { return { ...snap }; },
};
export const getScaleWeightWithFallback = async () => ({ weightKg: snap.weightKg, isStable: snap.isStable });
export const requestSerialPort = async () => {};
export const subscribeToScale = (cb: any) => { ouvintes.add(cb); return () => { ouvintes.delete(cb); }; };
export const ensureScaleAutoConnect = () => {};
export const getScaleRawLog = () => [];
export const clearScaleRawLog = () => {};
export const getScaleSnapshot = () => ({ ...snap });
export type ScaleStatus = string;
