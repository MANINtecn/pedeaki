-- Enable RLS on customers table
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Allow public access to insert new customers (needed for new orders)
CREATE POLICY "Enable insert for everyone" ON customers
FOR INSERT WITH CHECK (true);

-- Allow public access to read customers (needed for checking if customer exists)
CREATE POLICY "Enable select for everyone" ON customers
FOR SELECT USING (true);

-- Allow public access to update customers (needed for updating last order info)
CREATE POLICY "Enable update for everyone" ON customers
FOR UPDATE USING (true);

-- Ensure orders table also has correct policies (just in case)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert for everyone" ON orders
FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable select for everyone" ON orders
FOR SELECT USING (true);

CREATE POLICY "Enable update for everyone" ON orders
FOR UPDATE USING (true);
