-- Add table_number to orders if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'table_number') THEN
        ALTER TABLE orders ADD COLUMN table_number INTEGER;
    END IF;
END $$;
