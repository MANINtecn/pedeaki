-- Update the store slug to match the Vercel subdomain
UPDATE stores
SET slug = 'papaleguastocmg'
WHERE slug = 'papaleguas';

-- Verify the change
SELECT * FROM stores WHERE slug = 'papaleguastocmg';
