-- Add category_id column to addons table to allow linking addons to specific categories
ALTER TABLE addons
ADD COLUMN category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL;

-- Optional: Create an index for better performance
CREATE INDEX IF NOT EXISTS idx_addons_category_id ON addons(category_id);
