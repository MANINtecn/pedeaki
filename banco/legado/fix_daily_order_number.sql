-- Create a function to calculate the next daily order number
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_number INTEGER;
BEGIN
  -- Calculate the next number for the current store and today's date
  -- We cast timestamp to date to group by day
  SELECT COALESCE(MAX("dailyOrderNumber"), 0) + 1
  INTO next_number
  FROM orders
  WHERE store_id = NEW.store_id
    AND date(timestamp) = date(NEW.timestamp);

  -- Assign the calculated number to the new row
  NEW."dailyOrderNumber" := next_number;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger to call the function before insertion
DROP TRIGGER IF EXISTS trigger_set_daily_order_number ON orders;

CREATE TRIGGER trigger_set_daily_order_number
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION set_daily_order_number();
