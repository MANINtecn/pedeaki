-- Add rating and feedback columns to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS rating smallint,
ADD COLUMN IF NOT EXISTS feedback text;

-- Add check constraint for rating (1-5)
ALTER TABLE orders 
DROP CONSTRAINT IF EXISTS check_rating_range;

ALTER TABLE orders 
ADD CONSTRAINT check_rating_range CHECK (rating >= 1 AND rating <= 5);
