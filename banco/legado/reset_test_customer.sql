-- Reset data for test customer 32920007226
-- Delete orders first (foreign key constraint likely exists, but cascading might not be set, safest to delete children first)
DELETE FROM orders WHERE phone = '32920007226' OR phone = '920007226' OR customerName LIKE '%Icaro Teste%';

-- Delete customer record
DELETE FROM customers WHERE phone = '32920007226' OR phone = '920007226';
