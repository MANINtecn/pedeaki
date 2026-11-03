-- Create table to store pause states
CREATE TABLE IF NOT EXISTS public.ai_pauses (
    phone text PRIMARY KEY,
    expires_at timestamptz NOT NULL
);

-- Enable RLS (optional but good practice, though N8N uses service role usually)
ALTER TABLE public.ai_pauses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous read" ON public.ai_pauses FOR SELECT USING (true);
CREATE POLICY "Allow anonymous insert/update" ON public.ai_pauses FOR ALL USING (true);


-- Function to SET the pause (Block)
CREATE OR REPLACE FUNCTION public.set_ai_pause(p_phone text, p_seconds int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.ai_pauses (phone, expires_at)
    VALUES (p_phone, now() + (p_seconds || ' seconds')::interval)
    ON CONFLICT (phone) 
    DO UPDATE SET expires_at = EXCLUDED.expires_at;
END;
$$;


-- Function to CHECK if paused
CREATE OR REPLACE FUNCTION public.is_ai_paused(p_phone text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Delete expired records for cleanup (lazy expiration)
    DELETE FROM public.ai_pauses WHERE expires_at < now();

    -- Check if active record exists
    RETURN EXISTS (
        SELECT 1 
        FROM public.ai_pauses 
        WHERE phone = p_phone 
        AND expires_at > now()
    );
END;
$$;
