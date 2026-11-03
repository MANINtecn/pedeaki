-- FORCE FIX RLS POLICIES (Corrected)
-- Run this in Supabase SQL Editor

-- 1. CUSTOMERS TABLE
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Enable insert for everyone" ON customers;
DROP POLICY IF EXISTS "Enable select for everyone" ON customers;
DROP POLICY IF EXISTS "Enable update for everyone" ON customers;
DROP POLICY IF EXISTS "Public customers access" ON customers;
DROP POLICY IF EXISTS "Allow public insert" ON customers;
DROP POLICY IF EXISTS "Allow public select" ON customers;
DROP POLICY IF EXISTS "Allow public update" ON customers;
DROP POLICY IF EXISTS "Public Insert Customers" ON customers;
DROP POLICY IF EXISTS "Public Select Customers" ON customers;
DROP POLICY IF EXISTS "Public Update Customers" ON customers;


-- Create permissive policies
CREATE POLICY "Public Insert Customers" ON customers FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Select Customers" ON customers FOR SELECT USING (true);
CREATE POLICY "Public Update Customers" ON customers FOR UPDATE USING (true);

-- 2. ORDERS TABLE
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable insert for everyone" ON orders;
DROP POLICY IF EXISTS "Enable select for everyone" ON orders;
DROP POLICY IF EXISTS "Enable update for everyone" ON orders;
DROP POLICY IF EXISTS "Public orders access" ON orders;
DROP POLICY IF EXISTS "Public Insert Orders" ON orders;
DROP POLICY IF EXISTS "Public Select Orders" ON orders;
DROP POLICY IF EXISTS "Public Update Orders" ON orders;

-- Create permissive policies
CREATE POLICY "Public Insert Orders" ON orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Select Orders" ON orders FOR SELECT USING (true);
CREATE POLICY "Public Update Orders" ON orders FOR UPDATE USING (true);

-- Verify
select * from customers limit 1;
