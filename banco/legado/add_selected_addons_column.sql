ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS selected_addons JSONB DEFAULT '[]';
