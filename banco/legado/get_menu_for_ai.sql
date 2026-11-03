-- Function to get a text representation of the menu for AI consumption
DROP FUNCTION IF EXISTS get_menu_for_ai;

CREATE OR REPLACE FUNCTION get_menu_for_ai(p_store_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_menu_text TEXT := '';
    v_category RECORD;
    v_item RECORD;
    v_addon RECORD;
BEGIN
    v_menu_text := E'CARDÁPIO ATUALIZADO:\n\n';

    -- Loop through Promotions (New section)
    v_menu_text := v_menu_text || E'### PROMOÇÕES E COMBOS ATIVOS:\n';
    FOR v_item IN 
        SELECT * FROM promotions 
        WHERE store_id = p_store_id 
          AND "isActive" = true 
    LOOP
        v_menu_text := v_menu_text || '- ' || v_item.name || ': R$ ' || v_item.price || E'\n';
        IF v_item.description IS NOT NULL AND v_item.description <> '' THEN
             v_menu_text := v_menu_text || '  Desc: ' || v_item.description || E'\n';
        END IF;
    END LOOP;
    v_menu_text := v_menu_text || E'\n';

    -- Loop through Categories
    FOR v_category IN SELECT * FROM categories WHERE store_id = p_store_id ORDER BY name LOOP
        v_menu_text := v_menu_text || E'## ' || v_category.name || E'\n';
        
        -- Loop through Items in Category
        FOR v_item IN 
            SELECT * FROM menu_items 
            WHERE store_id = p_store_id 
              AND category_id = v_category.id 
              AND is_available = true 
            ORDER BY name 
        LOOP
            v_menu_text := v_menu_text || '- ' || v_item.name || ': R$ ' || v_item.price || E'\n';
            IF v_item.description IS NOT NULL AND v_item.description <> '' THEN
                 v_menu_text := v_menu_text || '  Desc: ' || v_item.description || E'\n';
            END IF;

            -- Fetch Addons for this item (if any)
            -- Assuming selected_addons is an array of IDs in JSONB or similar, 
            -- or if we have to query the addons table.
            -- Based on previous analysis, selected_addons is a JSONB array of IDs on the menu_item.
            
            IF jsonb_array_length(v_item.selected_addons) > 0 THEN
                v_menu_text := v_menu_text || '  Adicionais: ';
                FOR v_addon IN 
                    SELECT * FROM addons 
                    WHERE id IN (SELECT jsonb_array_elements_text(v_item.selected_addons)::UUID)
                LOOP
                     v_menu_text := v_menu_text || v_addon.name || ' (+R$ ' || v_addon.price || '), ';
                END LOOP;
                -- Remove trailing comma
                v_menu_text := substring(v_menu_text from 1 for length(v_menu_text)-2) || E'\n';
            END IF;
            
             v_menu_text := v_menu_text || E'\n';
        END LOOP;
    END LOOP;

    RETURN v_menu_text;
END;
$$;
