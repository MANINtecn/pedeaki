-- Add missing columns to the settings table

ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS "webhookArrivedAtDoorUrl" text,
ADD COLUMN IF NOT EXISTS "appDiscountPercentage" numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS "isAppDiscountEnabled" boolean DEFAULT false;

-- Verify the columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'settings';
