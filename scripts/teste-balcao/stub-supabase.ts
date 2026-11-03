// Banco falso em memoria, com latencia, no formato que o CounterTab espera.
const g: any = globalThis;
export const banco: { orders: any[]; seq: number; latencia: number; falhas: number } = (g.__banco ||= { orders: [], seq: 0, latencia: 150, falhas: 0 });
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const clone = (x: any) => JSON.parse(JSON.stringify(x));
export const criarNoBanco = async (order: any) => {
  await dormir(banco.latencia);
  if (banco.falhas > 0) { banco.falhas--; throw new Error("rede caiu"); }
  const o = clone({ ...order, id: order.id || `P${++banco.seq}`, status: order.status || "Novo", timestamp: new Date().toISOString() });
  banco.orders.push(o); return clone(o);
};
export const fetchAllOpenOrdersForTable = async (_s: string, mesa: number) => {
  await dormir(banco.latencia);
  return clone(banco.orders.filter(o => Number(o.table_number) === mesa && !["Entregue", "Cancelado"].includes(o.status)));
};
export const updateOrder = async (id: string, up: any) => { await dormir(banco.latencia); const o = banco.orders.find(x => x.id === id); if (o) Object.assign(o, clone(up)); return o; };
export const deleteOrder = async (id: string) => { await dormir(banco.latencia); banco.orders = banco.orders.filter(o => o.id !== id); };
export const fetchCustomerByPhone = async () => null;
export const upsertCustomer = async () => ({});
export const searchCustomers = async () => [];
export const clearTablePayments = async () => {};
