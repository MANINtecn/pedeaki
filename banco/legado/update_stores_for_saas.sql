-- Add SaaS management columns to the stores table
ALTER TABLE stores 
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS plan_value FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS owner_email TEXT;

-- Comment on columns
COMMENT ON COLUMN stores.subscription_end_date IS 'Date when the store subscription expires';
COMMENT ON COLUMN stores.plan_value IS 'Monthly value of the subscription plan';
COMMENT ON COLUMN stores.is_active IS 'Whether the store is active or suspended';
COMMENT ON COLUMN stores.owner_email IS 'Contact email for the store owner';
