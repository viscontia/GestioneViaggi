-- Function: check_possible_duplicate_travels
-- Description: Identifies potential duplicate trips based on word matches in descriptive fields.
-- Returns: A table of similar trips and the matching words.

CREATE OR REPLACE FUNCTION check_possible_duplicate_travels(
    p_description text,
    p_azienda_id integer
)
RETURNS TABLE (
    viaggio_id integer,
    viaggio_descrizione_breve character varying,
    matching_words text
) AS $$
DECLARE
    v_search_words text[];
    v_word text;
BEGIN
    -- 1. Normalization and Tokenization
    -- Convert to uppercase, remove special chars, split by space
    -- We filter valid words: length > 3 to avoid articles/conjunctions
    SELECT ARRAY_AGG(DISTINCT w) INTO v_search_words
    FROM regexp_split_to_table(upper(p_description), '\s+') AS w
    WHERE length(w) > 3;

    -- If no valid words found, return empty
    IF v_search_words IS NULL THEN
        RETURN;
    END IF;

    -- 2. Search for matches
    RETURN QUERY
    SELECT 
        v.viaggio_id,
        v.viaggio_descrizione_breve,
        string_agg(DISTINCT word, ', ') as matching_words
    FROM 
        ana_viaggi v,
        unnest(v_search_words) AS word
    WHERE 
        v.azienda_id = p_azienda_id
        -- Match word in DB description (ILIKE for case-insensitive partial match or exact word match logic)
        -- Here we check if the DB description CONTAINS the word
        AND v.viaggio_descrizione_breve ILIKE '%' || word || '%'
    GROUP BY 
        v.viaggio_id, v.viaggio_descrizione_breve;
END;
$$ LANGUAGE plpgsql;
