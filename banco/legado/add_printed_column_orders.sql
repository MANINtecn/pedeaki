-- Add printed column to orders table if it doesn't exist
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS printed BOOLEAN DEFAULT FALSE;
