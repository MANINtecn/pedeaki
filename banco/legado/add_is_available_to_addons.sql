-- Add is_available column to addons table
ALTER TABLE addons
ADD COLUMN is_available BOOLEAN DEFAULT true;

-- Update existing records to be available by default
UPDATE addons SET is_available = true WHERE is_available IS NULL;
