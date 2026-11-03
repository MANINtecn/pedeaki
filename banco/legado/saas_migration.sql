-- 1. Create 'stores' table
CREATE TABLE IF NOT EXISTS stores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    owner_id UUID REFERENCES auth.users(id), -- Link to Supabase Auth User
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    logo_url TEXT,
    theme_colors JSONB DEFAULT '{"primary": "#FFD700", "secondary": "#D32F2F", "background": "#121212", "surface": "#1E1E1E"}'::jsonb
);

-- 2. Insert Default Store (Papaléguas)
-- We need to insert it first to get its ID for migration
INSERT INTO stores (name, slug)
VALUES ('Papaléguas Lanches', 'papaleguas')
ON CONFLICT (slug) DO NOTHING;

-- Capture the ID of the default store
DO $$
DECLARE
    default_store_id UUID;
BEGIN
    SELECT id INTO default_store_id FROM stores WHERE slug = 'papaleguas';

    -- 3. Add 'store_id' to existing tables and set default value
    
    -- Categories
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'categories' AND column_name = 'store_id') THEN
        ALTER TABLE categories ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE categories SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE categories ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Menu Items
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'store_id') THEN
        ALTER TABLE menu_items ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE menu_items SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE menu_items ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Addons
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'addons' AND column_name = 'store_id') THEN
        ALTER TABLE addons ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE addons SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE addons ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Orders
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'store_id') THEN
        ALTER TABLE orders ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE orders SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE orders ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Promotions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'promotions' AND column_name = 'store_id') THEN
        ALTER TABLE promotions ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE promotions SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE promotions ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Cash Sessions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cash_sessions' AND column_name = 'store_id') THEN
        ALTER TABLE cash_sessions ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE cash_sessions SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE cash_sessions ALTER COLUMN store_id SET NOT NULL;
    END IF;
    
    -- Cash Transactions (Optional, usually linked to session, but good for redundancy)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cash_transactions' AND column_name = 'store_id') THEN
        ALTER TABLE cash_transactions ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE cash_transactions SET store_id = default_store_id WHERE store_id IS NULL;
        ALTER TABLE cash_transactions ALTER COLUMN store_id SET NOT NULL;
    END IF;

    -- Settings
    -- Settings table currently has id=1 fixed. We need to migrate this.
    -- For now, let's add store_id.
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'store_id') THEN
        ALTER TABLE settings ADD COLUMN store_id UUID REFERENCES stores(id);
        UPDATE settings SET store_id = default_store_id WHERE store_id IS NULL;
        -- We don't enforce NOT NULL yet because settings might be weird with the single row constraint
    END IF;

END $$;
