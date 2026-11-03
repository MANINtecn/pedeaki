-- 1. Create the 'couriers' table
CREATE TABLE IF NOT EXISTS couriers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id UUID NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    password TEXT NOT NULL, -- Storing as text for simplicity as requested (or hash if preferred)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Add Unique constraint on phone per store (optional, but good practice)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_couriers_phone_store ON couriers(phone, store_id);

-- 3. Update 'orders' table to link couriers
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS courier_id UUID REFERENCES couriers(id),
ADD COLUMN IF NOT EXISTS courier_name TEXT;

-- 4. Enable RLS (Row Level Security) - Optional but recommended
ALTER TABLE couriers ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read/write for now to facilitate the "simple login" flow 
-- (In a real app, strict policies would be applied)
CREATE POLICY "Enable access to all users" ON couriers FOR ALL USING (true) WITH CHECK (true);
