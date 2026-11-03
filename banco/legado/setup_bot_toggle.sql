-- Create AI Settings table
CREATE TABLE IF NOT EXISTS public.ai_settings (
    store_id UUID PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
    is_bot_enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.ai_settings ENABLE ROW LEVEL SECURITY;

-- Simple policy for staff/admins
CREATE POLICY "Allow authenticated access to ai_settings" 
ON public.ai_settings FOR ALL 
USING (auth.role() = 'authenticated');

-- Function to check bot status (used by N8N)
CREATE OR REPLACE FUNCTION public.get_bot_status_rpc(p_store_id UUID)
RETURNS JSON AS $$
DECLARE
    v_status BOOLEAN;
BEGIN
    SELECT is_bot_enabled INTO v_status 
    FROM public.ai_settings 
    WHERE store_id = p_store_id;

    -- If no setting exists, create it as true
    IF v_status IS NULL THEN
        INSERT INTO public.ai_settings (store_id, is_bot_enabled)
        VALUES (p_store_id, true)
        RETURNING is_bot_enabled INTO v_status;
    END IF;

    RETURN json_build_object('is_bot_enabled', v_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to toggle bot status (used by Frontend)
CREATE OR REPLACE FUNCTION public.toggle_bot_status(p_store_id UUID, p_status BOOLEAN)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO public.ai_settings (store_id, is_bot_enabled)
    VALUES (p_store_id, p_status)
    ON CONFLICT (store_id) 
    DO UPDATE SET is_bot_enabled = p_status, updated_at = now();
    
    RETURN p_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
