-- Add raffleDrawDate column to the settings table

ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS "raffleDrawDate" text;

-- Verify the column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'settings' AND column_name = 'raffleDrawDate';
