
-- Script to add ALL printer-related columns to the settings table
-- Safe to run multiple times (uses IF NOT EXISTS)

DO $$ 
BEGIN 
    -- 1. Add preferred_printer (Primary Printer)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'preferred_printer') THEN
        ALTER TABLE settings ADD COLUMN preferred_printer text;
    END IF;

    -- 2. Add printer_paper_width (Primary Printer Width)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'printer_paper_width') THEN
        ALTER TABLE settings ADD COLUMN printer_paper_width text DEFAULT '80mm';
    END IF;

    -- 3. Add kitchen_printer (Kitchen Printer)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'kitchen_printer') THEN
        ALTER TABLE settings ADD COLUMN kitchen_printer text;
    END IF;

    -- 4. Add kitchen_printer_paper_width
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'kitchen_printer_paper_width') THEN
        ALTER TABLE settings ADD COLUMN kitchen_printer_paper_width text DEFAULT '80mm';
    END IF;

    -- 5. Add bar_printer (Bar Printer)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'bar_printer') THEN
        ALTER TABLE settings ADD COLUMN bar_printer text;
    END IF;

    -- 6. Add bar_printer_paper_width
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'bar_printer_paper_width') THEN
        ALTER TABLE settings ADD COLUMN bar_printer_paper_width text DEFAULT '80mm';
    END IF;

    -- 7. Add courier_printer (Courier Printer)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'courier_printer') THEN
        ALTER TABLE settings ADD COLUMN courier_printer text;
    END IF;

    -- 8. Add courier_printer_paper_width
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'courier_printer_paper_width') THEN
        ALTER TABLE settings ADD COLUMN courier_printer_paper_width text DEFAULT '80mm';
    END IF;

    -- 9. Add printer_compatibility_mode
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'printer_compatibility_mode') THEN
        ALTER TABLE settings ADD COLUMN printer_compatibility_mode boolean DEFAULT false;
    END IF;
    
    -- 10. Add is_bot_enabled (Just in case)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'is_bot_enabled') THEN
        ALTER TABLE settings ADD COLUMN is_bot_enabled boolean DEFAULT true;
    END IF;

END $$;
