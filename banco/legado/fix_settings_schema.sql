
-- Script to unify settings table schema to snake_case and add missing columns

-- 1. Add missing days_of_week column
ALTER TABLE settings ADD COLUMN IF NOT EXISTS days_of_week JSONB DEFAULT '["0", "1", "2", "3", "4", "5", "6"]';

-- 2. Rename/Unify columns if they exist in camelCase
DO $$ 
BEGIN
    -- openingTime -> opening_time
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'openingTime') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'opening_time') THEN
            ALTER TABLE settings RENAME COLUMN "openingTime" TO opening_time;
        ELSE
            UPDATE settings SET opening_time = "openingTime" WHERE opening_time IS NULL;
            ALTER TABLE settings DROP COLUMN "openingTime";
        END IF;
    END IF;

    -- closingTime -> closing_time
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'closingTime') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'closing_time') THEN
            ALTER TABLE settings RENAME COLUMN "closingTime" TO closing_time;
        ELSE
            UPDATE settings SET closing_time = "closingTime" WHERE closing_time IS NULL;
            ALTER TABLE settings DROP COLUMN "closingTime";
        END IF;
    END IF;

    -- manualStatus -> manual_status
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'manualStatus') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'manual_status') THEN
            ALTER TABLE settings RENAME COLUMN "manualStatus" TO manual_status;
        ELSE
            UPDATE settings SET manual_status = "manualStatus" WHERE manual_status IS NULL;
            ALTER TABLE settings DROP COLUMN "manualStatus";
        END IF;
    END IF;

    -- comboPrice -> combo_price
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'comboPrice') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'combo_price') THEN
            ALTER TABLE settings RENAME COLUMN "comboPrice" TO combo_price;
        ELSE
            UPDATE settings SET combo_price = "comboPrice" WHERE combo_price IS NULL;
            ALTER TABLE settings DROP COLUMN "comboPrice";
        END IF;
    END IF;

    -- webhookNewOrderUrl -> webhook_new_order_url
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhookNewOrderUrl') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhook_new_order_url') THEN
            ALTER TABLE settings RENAME COLUMN "webhookNewOrderUrl" TO webhook_new_order_url;
        ELSE
            UPDATE settings SET webhook_new_order_url = "webhookNewOrderUrl" WHERE webhook_new_order_url IS NULL;
            ALTER TABLE settings DROP COLUMN "webhookNewOrderUrl";
        END IF;
    END IF;

    -- webhookInProductionUrl -> webhook_in_production_url
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhookInProductionUrl') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhook_in_production_url') THEN
            ALTER TABLE settings RENAME COLUMN "webhookInProductionUrl" TO webhook_in_production_url;
        ELSE
            UPDATE settings SET webhook_in_production_url = "webhookInProductionUrl" WHERE webhook_in_production_url IS NULL;
            ALTER TABLE settings DROP COLUMN "webhookInProductionUrl";
        END IF;
    END IF;

    -- webhookOutForDeliveryUrl -> webhook_out_for_delivery_url
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhookOutForDeliveryUrl') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhook_out_for_delivery_url') THEN
            ALTER TABLE settings RENAME COLUMN "webhookOutForDeliveryUrl" TO webhook_out_for_delivery_url;
        ELSE
            UPDATE settings SET webhook_out_for_delivery_url = "webhookOutForDeliveryUrl" WHERE webhook_out_for_delivery_url IS NULL;
            ALTER TABLE settings DROP COLUMN "webhookOutForDeliveryUrl";
        END IF;
    END IF;

    -- webhookArrivedAtDoorUrl -> webhook_arrived_at_door_url
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhookArrivedAtDoorUrl') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'webhook_arrived_at_door_url') THEN
            ALTER TABLE settings RENAME COLUMN "webhookArrivedAtDoorUrl" TO webhook_arrived_at_door_url;
        ELSE
            UPDATE settings SET webhook_arrived_at_door_url = "webhookArrivedAtDoorUrl" WHERE webhook_arrived_at_door_url IS NULL;
            ALTER TABLE settings DROP COLUMN "webhookArrivedAtDoorUrl";
        END IF;
    END IF;

    -- appDiscountPercentage -> app_discount_percentage
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'appDiscountPercentage') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'app_discount_percentage') THEN
            ALTER TABLE settings RENAME COLUMN "appDiscountPercentage" TO app_discount_percentage;
        ELSE
            UPDATE settings SET app_discount_percentage = "appDiscountPercentage" WHERE app_discount_percentage IS NULL;
            ALTER TABLE settings DROP COLUMN "appDiscountPercentage";
        END IF;
    END IF;

    -- isAppDiscountEnabled -> is_app_discount_enabled
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'isAppDiscountEnabled') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'is_app_discount_enabled') THEN
            ALTER TABLE settings RENAME COLUMN "isAppDiscountEnabled" TO is_app_discount_enabled;
        ELSE
            UPDATE settings SET is_app_discount_enabled = "isAppDiscountEnabled" WHERE is_app_discount_enabled IS NULL;
            ALTER TABLE settings DROP COLUMN "isAppDiscountEnabled";
        END IF;
    END IF;

END $$;

-- 3. Final verification of column existence
ALTER TABLE settings ADD COLUMN IF NOT EXISTS opening_time TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS closing_time TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS manual_status TEXT DEFAULT 'auto';
ALTER TABLE settings ADD COLUMN IF NOT EXISTS combo_price DECIMAL DEFAULT 13.00;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS webhook_new_order_url TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS webhook_in_production_url TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS webhook_out_for_delivery_url TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS webhook_arrived_at_door_url TEXT;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS app_discount_percentage DECIMAL DEFAULT 0;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS is_app_discount_enabled BOOLEAN DEFAULT false;
