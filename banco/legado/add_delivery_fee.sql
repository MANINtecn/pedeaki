-- Add delivery_fee to settings (Global config)
ALTER TABLE public.settings ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC DEFAULT 2.00;

-- Add delivery_fee to orders (Historical record)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC DEFAULT 0;
