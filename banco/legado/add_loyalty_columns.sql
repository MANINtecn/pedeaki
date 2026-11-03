-- Add loyalty columns to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_loyalty_eligible BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS loyalty_redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Backfill existing eligible orders (Total >= 35.00 and Status = 'Entregue')
-- CRITICAL: We also normalize the phone number to remove non-numeric characters (parentheses, dashes, spaces)
-- This prevents the 'validate_phone_trigger' from failing due to legacy formatted numbers.
-- (Removed backfill to start loyalty from zero)

-- Create index for performance queries on loyalty history
CREATE INDEX IF NOT EXISTS idx_orders_loyalty ON orders(phone, is_loyalty_eligible, loyalty_redeemed_at);
