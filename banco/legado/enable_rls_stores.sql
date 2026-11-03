-- Enable RLS on stores table
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

-- Allow public read access (necessary for loading store config)
CREATE POLICY "Public Read Access" ON public.stores
FOR SELECT
TO public
USING (true);

-- Allow authenticated users (admins) to update/insert
CREATE POLICY "Admin All Access" ON public.stores
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
