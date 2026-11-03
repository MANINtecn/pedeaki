-- CHECK FOR TRIGGERS ON THE ORDERS TABLE
SELECT 
    tgname AS trigger_name,
    proname AS function_name,
    prosrc AS function_body
FROM pg_trigger
JOIN pg_proc ON pg_proc.oid = pg_trigger.tgfoid
WHERE tgrelid = 'orders'::regclass;

-- CHECK FOR ALL FUNCTIONS REFERRING TO dailyOrderNumber
SELECT 
    proname AS function_name,
    prosrc AS function_body
FROM pg_proc
WHERE prosrc ILIKE '%dailyOrderNumber%';
