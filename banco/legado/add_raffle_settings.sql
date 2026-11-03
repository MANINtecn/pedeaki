-- Add raffle settings columns to the settings table

ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS "isRaffleEnabled" boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS "rafflePrizeValue" numeric DEFAULT 0;

-- Verify the columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'settings';
