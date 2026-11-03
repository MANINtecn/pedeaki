-- Enable RLS logic for orders to be safe, but allow Public Read for Motoboy
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Allow ANYONE (including Motoboy without login) to READ orders
-- Ideally we would restrict by store_id, but for now we trust the client filter
CREATE POLICY "Public Read Orders" ON public.orders
FOR SELECT
TO public
USING (true);

-- Allow Authenticated Users (Admins) to do EVERYTHING
CREATE POLICY "Admin All Access Orders" ON public.orders
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Allow Public (Customers) to CREATE orders (INSERT)
CREATE POLICY "Public Create Orders" ON public.orders
FOR INSERT
TO public
WITH CHECK (true);

-- Allow Public (Customers/Motoboy) to UPDATE orders (e.g. status)
-- WARNING: This is permissive. In production, restrict columns.
CREATE POLICY "Public Update Orders" ON public.orders
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);
