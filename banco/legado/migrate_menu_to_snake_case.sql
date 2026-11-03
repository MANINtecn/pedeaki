-- MIGRATION: RENAME COLUMNS TO SNAKE_CASE FOR MENU_ITEMS AND ADDONS
-- This script fixes the PGRST204 error by aligning DB column names with the frontend.

DO $$ 
BEGIN
    -- 1. Fix 'menu_items' table
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'categoryId') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'category_id') THEN
            ALTER TABLE menu_items RENAME COLUMN "categoryId" TO category_id;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "categoryId";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'isAvailable') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'is_available') THEN
            ALTER TABLE menu_items RENAME COLUMN "isAvailable" TO is_available;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "isAvailable";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'eligibleForCombo') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'eligible_for_combo') THEN
            ALTER TABLE menu_items RENAME COLUMN "eligibleForCombo" TO eligible_for_combo;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "eligibleForCombo";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'isCombo') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'is_combo') THEN
            ALTER TABLE menu_items RENAME COLUMN "isCombo" TO is_combo;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "isCombo";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'allowedAddons') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'allowed_addons') THEN
            ALTER TABLE menu_items RENAME COLUMN "allowedAddons" TO allowed_addons;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "allowedAddons";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'selectedAddons') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'selected_addons') THEN
            ALTER TABLE menu_items RENAME COLUMN "selectedAddons" TO selected_addons;
        ELSE
            ALTER TABLE menu_items DROP COLUMN "selectedAddons";
        END IF;
    END IF;

    -- 2. Fix 'addons' table
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'addons' AND column_name = 'categoryId') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'addons' AND column_name = 'category_id') THEN
            ALTER TABLE addons RENAME COLUMN "categoryId" TO category_id;
        ELSE
            ALTER TABLE addons DROP COLUMN "categoryId";
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'addons' AND column_name = 'isAvailable') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'addons' AND column_name = 'is_available') THEN
            ALTER TABLE addons RENAME COLUMN "isAvailable" TO is_available;
        ELSE
            ALTER TABLE addons DROP COLUMN "isAvailable";
        END IF;
    END IF;

END $$;

-- 3. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';
