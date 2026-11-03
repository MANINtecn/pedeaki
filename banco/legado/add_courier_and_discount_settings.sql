ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS app_discount_percentage FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_app_discount_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS webhook_arrived_at_door_url TEXT;
