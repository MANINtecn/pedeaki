-- Enable RLS logic for orders (idempotent)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- DROP existing policies to avoid "already exists" errors
DROP POLICY IF EXISTS "Public Read Orders" ON public.orders;
DROP POLICY IF EXISTS "Admin All Access Orders" ON public.orders;
DROP POLICY IF EXISTS "Public Create Orders" ON public.orders;
DROP POLICY IF EXISTS "Public Update Orders" ON public.orders;

-- NOW Re-create them

-- Allow ANYONE (including Motoboy without login) to READ orders
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
CREATE POLICY "Public Update Orders" ON public.orders
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);
