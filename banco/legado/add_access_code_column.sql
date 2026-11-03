
-- Add courier_access_code column to settings table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'courier_access_code') THEN
        ALTER TABLE settings ADD COLUMN courier_access_code VARCHAR(255);
    END IF;
END $$;
