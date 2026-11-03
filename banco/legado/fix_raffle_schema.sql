-- Add raffle columns in correct snake_case format
ALTER TABLE settings 
ADD COLUMN IF NOT EXISTS is_raffle_enabled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS raffle_prize_value numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS raffle_draw_date text,
ADD COLUMN IF NOT EXISTS last_raffle_winner text;

-- Drop camelCase columns if they exist to avoid confusion
ALTER TABLE settings 
DROP COLUMN IF EXISTS "isRaffleEnabled",
DROP COLUMN IF EXISTS "rafflePrizeValue",
DROP COLUMN IF EXISTS "raffleDrawDate",
DROP COLUMN IF EXISTS "lastRaffleWinner";

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'settings';
