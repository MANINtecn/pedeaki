-- Create Customers Table
CREATE TABLE IF NOT EXISTS customers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  name TEXT,
  address TEXT,
  reference_point TEXT,
  total_orders INTEGER DEFAULT 0,
  last_order_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(store_id, phone)
);

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public can view customers" ON customers FOR SELECT USING (true);
CREATE POLICY "Admins can manage customers" ON customers FOR ALL USING (auth.role() = 'authenticated');

-- Trigger to Auto-Update Customers on New Order
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
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    reference_point = EXCLUDED.reference_point,
    total_orders = customers.total_orders + 1,
    last_order_at = EXCLUDED.last_order_at;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_customer ON orders;

CREATE TRIGGER trigger_update_customer
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION update_customer_on_order();
