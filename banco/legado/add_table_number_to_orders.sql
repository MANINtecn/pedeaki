-- Add table_number column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number INTEGER;

-- Add comandaNumber column if it doesn't exist (using camelCase as seen in other columns)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS "comandaNumber" INTEGER;
