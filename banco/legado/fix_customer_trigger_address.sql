-- Fix for Bug: Pickup orders (with empty address) overwriting customer's saved address
-- This updates the trigger function to only update address/reference if the new value is NOT empty.

CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
  VALUES (
    NEW.store_id,
    NEW.phone,
    NEW."customerName",
    NEW.address,
    NEW."referencePoint",
    1,
    NEW.timestamp
  )
  ON CONFLICT (store_id, phone)
  DO UPDATE SET
    name = COALESCE(NULLIF(EXCLUDED.name, ''), customers.name),
    address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
    reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
    total_orders = customers.total_orders + 1,
    last_order_at = EXCLUDED.last_order_at;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
