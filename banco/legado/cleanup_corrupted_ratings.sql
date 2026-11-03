
-- SQL script to cleanup corrupted rating data in orders table
UPDATE orders 
SET rating = NULL 
WHERE rating > 5 OR rating < 1;
