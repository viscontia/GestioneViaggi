-- ============================================================================
-- RICOVERO — definizioni delle funzioni rimosse dallo script 626
-- Generato il 2026-09-07 dal database locale.
--
-- ⛔️ NON APPLICARE. Questo file non sta in SqlScripts/ apposta: il ciclo di
--    go-live applica tutto quello che trova li' dentro, e applicare questo
--    ricreerebbe esattamente cio' che il 626 ha tolto.
--
-- A che serve: molte di queste funzioni non comparivano in NESSUNO script —
-- esistevano solo dentro il database. Senza questo file, toglierle sarebbe
-- stato irreversibile. Qui restano leggibili e tracciate da git, se un domani
-- servisse ripartire da una di loro (in particolare la famiglia geografica e
-- l'IVA, quando si affrontera' l'SQL scritto dentro il C# — §2.18).
-- ============================================================================


-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_access_azienda(target_azienda_id integer)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT CASE 
        -- SuperAdmin può vedere tutto
        WHEN current_setting('app.role_code', true) = 'superadmin' THEN true
        -- TenantAdmin può vedere tutte le aziende del suo tenant
        WHEN current_setting('app.role_code', true) IN ('tenant_admin', 'tenant_user') THEN true  
        -- Ruoli azienda-specifici possono vedere solo la loro azienda
        WHEN current_setting('app.role_code', true) IN ('azienda_admin', 'azienda_user', 'azienda_readonly') 
        THEN target_azienda_id = current_setting('app.azienda_id', true)::integer
        -- Readonly può vedere tutto (cross-tenant, da verificare se è il comportamento desiderato)
        WHEN current_setting('app.role_code', true) = 'readonly' THEN true
        ELSE false
    END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_azienda()
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
    SELECT CASE 
        WHEN current_setting('app.azienda_id', true) = '' THEN NULL
        ELSE current_setting('app.azienda_id', true)::integer
    END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public."current_role"()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
    SELECT current_setting('app.role_code', true)::text;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
    SELECT current_setting('app.user_id', true)::uuid;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ana_aliquote_iva_get_active(p_azienda_id integer)
 RETURNS SETOF ana_aliquote_iva
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
      AND is_active = TRUE
    ORDER BY ordinamento, iva_descrizione;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ana_aliquote_iva_get_all(p_azienda_id integer)
 RETURNS SETOF ana_aliquote_iva
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
    ORDER BY ordinamento, iva_descrizione;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ana_aliquote_iva_get_default(p_azienda_id integer)
 RETURNS ana_aliquote_iva
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result ana_aliquote_iva;
BEGIN
    SELECT *
    INTO v_result
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
      AND is_default = TRUE
    LIMIT 1;

    RETURN v_result;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_aziende(p_user_id uuid DEFAULT NULL::uuid, p_page_number integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search_term text DEFAULT NULL::text, p_sort_column text DEFAULT 'ragione_sociale'::text, p_sort_direction text DEFAULT 'ASC'::text, p_filters jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_offset integer;
    v_limit integer;
    v_where_clause text := '';
    v_order_clause text;
    v_query text;
    v_count_query text;
    v_total_count integer;
    v_result jsonb;
    v_data jsonb[];
    v_record record;
BEGIN
    -- Calcolo offset e limit
    v_limit := LEAST(p_page_size, 100); -- Max 100 per pagina
    v_offset := (p_page_number - 1) * v_limit;
    
    -- Validazione colonna sort
    IF p_sort_column NOT IN ('ragione_sociale', 'tenant_id', 'forma_giuridica', 'partita_iva', 
                             'codice_fiscale', 'capitale_sociale', 'attivo', 'data_creazione', 'data_ultima_modifica') THEN
        p_sort_column := 'ragione_sociale';
    END IF;
    
    -- Validazione direzione sort
    IF p_sort_direction NOT IN ('ASC', 'DESC') THEN
        p_sort_direction := 'ASC';
    END IF;
    
    -- Costruzione WHERE clause per ricerca globale
    IF p_search_term IS NOT NULL AND length(trim(p_search_term)) > 0 THEN
        v_where_clause := v_where_clause || ' AND (
            ragione_sociale ILIKE ''%' || p_search_term || '%'' OR
            tenant_id ILIKE ''%' || p_search_term || '%'' OR
            forma_giuridica ILIKE ''%' || p_search_term || '%'' OR
            partita_iva ILIKE ''%' || p_search_term || '%'' OR
            codice_fiscale ILIKE ''%' || p_search_term || '%'' OR
            pec ILIKE ''%' || p_search_term || '%'' OR
            sito_web ILIKE ''%' || p_search_term || '%''
        )';
    END IF;
    
    -- Costruzione filtri specifici da JSON
    IF p_filters IS NOT NULL THEN
        -- Filtro stato attivo
        IF p_filters ? 'attivo' THEN
            v_where_clause := v_where_clause || ' AND attivo = ' || (p_filters->>'attivo')::boolean;
        END IF;
        
        -- Filtro forma giuridica
        IF p_filters ? 'forma_giuridica' AND jsonb_array_length(p_filters->'forma_giuridica') > 0 THEN
            v_where_clause := v_where_clause || ' AND forma_giuridica = ANY(''' || 
                (SELECT array_agg(value#>>'{}') FROM jsonb_array_elements(p_filters->'forma_giuridica'))::text || ''')';
        END IF;
        
        -- Filtro socio unico
        IF p_filters ? 'socio_unico' THEN
            v_where_clause := v_where_clause || ' AND socio_unico = ' || (p_filters->>'socio_unico')::boolean;
        END IF;
        
        -- Filtro in liquidazione
        IF p_filters ? 'in_liquidazione' THEN
            v_where_clause := v_where_clause || ' AND in_liquidazione = ' || (p_filters->>'in_liquidazione')::boolean;
        END IF;
    END IF;
    
    -- Costruzione ORDER BY
    v_order_clause := ' ORDER BY ' || p_sort_column || ' ' || p_sort_direction;
    
    -- Query per conteggio totale
    v_count_query := 'SELECT COUNT(*) FROM public.ana_aziende WHERE 1=1' || v_where_clause;
    EXECUTE v_count_query INTO v_total_count;
    
    -- Query principale per dati
    v_query := '
        SELECT 
            azienda_id,
            tenant_id,
            ragione_sociale,
            forma_giuridica,
            data_costituzione,
            data_inizio_attivita,
            capitale_sociale,
            socio_unico,
            in_liquidazione,
            partita_iva,
            codice_fiscale,
            rea_provincia_fk,
            rea_numero,
            rea_data_iscrizione,
            codice_destinatario_sdi,
            pec,
            sito_web,
            telefono_principale,
            attivo,
            data_creazione,
            data_ultima_modifica
        FROM public.ana_aziende 
        WHERE 1=1' || v_where_clause || v_order_clause || ' LIMIT ' || v_limit || ' OFFSET ' || v_offset;
    
    -- Esecuzione query e costruzione array risultati
    v_data := ARRAY[]::jsonb[];
    FOR v_record IN EXECUTE v_query LOOP
        v_data := array_append(v_data, row_to_json(v_record)::jsonb);
    END LOOP;
    
    -- Costruzione risposta JSON:API compliant
    v_result := jsonb_build_object(
        'success', true,
        'data', array_to_json(v_data)::jsonb,
        'meta', jsonb_build_object(
            'pagination', jsonb_build_object(
                'page', p_page_number,
                'pageSize', v_limit,
                'totalCount', v_total_count,
                'totalPages', CEIL(v_total_count::numeric / v_limit::numeric),
                'hasNext', (p_page_number * v_limit) < v_total_count,
                'hasPrev', p_page_number > 1
            ),
            'filters', COALESCE(p_filters, '{}'::jsonb),
            'sort', jsonb_build_object(
                'column', p_sort_column,
                'direction', p_sort_direction
            )
        )
    );
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'DATABASE_ERROR',
            'detail', SQLERRM
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_aziende()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'success', true,
    'aziende', (
      SELECT COALESCE(jsonb_agg(row_to_json(a)), '[]'::jsonb)
      FROM public.ana_aziende a
    )
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_countries(p_tenant_id character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_search text DEFAULT NULL::text, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_offset INTEGER;
    v_total_count INTEGER;
    v_result JSONB;
    v_data JSONB;
BEGIN
    -- Validazione parametri
    IF p_page < 1 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'INVALID_PAGE',
                'message', 'Il numero di pagina deve essere maggiore di 0',
                'field', 'page'
            )
        );
    END IF;

    IF p_page_size < 1 OR p_page_size > 1000 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'INVALID_PAGE_SIZE',
                'message', 'La dimensione della pagina deve essere tra 1 e 1000',
                'field', 'page_size'
            )
        );
    END IF;

    -- Calcola offset
    v_offset := (p_page - 1) * p_page_size;

    -- Conta totale record
    SELECT COUNT(*)
    INTO v_total_count
    FROM eba_countries
    WHERE (p_search IS NULL OR
           name ILIKE '%' || p_search || '%' OR
           nationality ILIKE '%' || p_search || '%' OR
           country_code ILIKE '%' || p_search || '%' OR
           iso_alpha2 ILIKE '%' || p_search || '%');

    -- Recupera dati con paginazione e JOIN con eba_country_organizations
    SELECT jsonb_agg(
        jsonb_build_object(
            'country_id', c.country_id,
            'name', c.name,
            'nationality', c.nationality,
            'country_code', c.country_code,
            'iso_alpha2', c.iso_alpha2,
            'capital', c.capital,
            'population', c.population,
            'area_km2', c.area_km2,
            'region_id', c.region_id,
            'sub_region_id', c.sub_region_id,
            'intermediate_region_id', c.intermediate_region_id,
            'organization_region_id', c.organization_region_id,
            'organization_name', org.name
        ) ORDER BY
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'ASC' THEN c.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'DESC' THEN c.name END DESC,
            CASE WHEN p_sort_by = 'country_code' AND p_sort_order = 'ASC' THEN c.country_code END ASC,
            CASE WHEN p_sort_by = 'country_code' AND p_sort_order = 'DESC' THEN c.country_code END DESC,
            CASE WHEN p_sort_by = 'population' AND p_sort_order = 'ASC' THEN c.population END ASC,
            CASE WHEN p_sort_by = 'population' AND p_sort_order = 'DESC' THEN c.population END DESC
    )
    INTO v_data
    FROM (
        SELECT c.*
        FROM eba_countries c
        WHERE (p_search IS NULL OR
               c.name ILIKE '%' || p_search || '%' OR
               c.nationality ILIKE '%' || p_search || '%' OR
               c.country_code ILIKE '%' || p_search || '%' OR
               c.iso_alpha2 ILIKE '%' || p_search || '%')
        LIMIT p_page_size
        OFFSET v_offset
    ) c
    LEFT JOIN eba_country_organizations org ON org.id = c.organization_region_id;

    -- Costruisci risultato
    v_result := jsonb_build_object(
        'success', true,
        'data', COALESCE(v_data, '[]'::jsonb),
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_count,
            'total_pages', CEIL(v_total_count::NUMERIC / p_page_size)
        )
    );

    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'DATABASE_ERROR',
                'message', 'Errore durante il recupero delle nazioni',
                'details', SQLERRM
            )
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_country_organizations(p_tenant_id character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_search text DEFAULT NULL::text, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_offset INTEGER;
    v_total_count INTEGER;
    v_result JSONB;
    v_data JSONB;
BEGIN
    -- Validazione parametri
    IF p_page < 1 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'INVALID_PAGE',
                'message', 'Il numero di pagina deve essere maggiore di 0',
                'field', 'page'
            )
        );
    END IF;

    IF p_page_size < 1 OR p_page_size > 1000 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'INVALID_PAGE_SIZE',
                'message', 'La dimensione della pagina deve essere tra 1 e 1000',
                'field', 'page_size'
            )
        );
    END IF;

    -- Calcola offset
    v_offset := (p_page - 1) * p_page_size;

    -- Conta totale record
    SELECT COUNT(*)
    INTO v_total_count
    FROM eba_country_organizations
    WHERE (p_search IS NULL OR
           name ILIKE '%' || p_search || '%' OR
           code ILIKE '%' || p_search || '%');

    -- Recupera dati con paginazione
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'code', code,
            'name', name
        ) ORDER BY
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'ASC' THEN name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'DESC' THEN name END DESC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order = 'ASC' THEN code END ASC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order = 'DESC' THEN code END DESC,
            CASE WHEN p_sort_by = 'id' AND p_sort_order = 'ASC' THEN id END ASC,
            CASE WHEN p_sort_by = 'id' AND p_sort_order = 'DESC' THEN id END DESC
    )
    INTO v_data
    FROM (
        SELECT *
        FROM eba_country_organizations
        WHERE (p_search IS NULL OR
               name ILIKE '%' || p_search || '%' OR
               code ILIKE '%' || p_search || '%')
        LIMIT p_page_size
        OFFSET v_offset
    ) sub;

    -- Costruisci risultato
    v_result := jsonb_build_object(
        'success', true,
        'data', COALESCE(v_data, '[]'::jsonb),
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_count,
            'total_pages', CEIL(v_total_count::NUMERIC / p_page_size)
        )
    );

    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'DATABASE_ERROR',
                'message', 'Errore durante il recupero delle organizzazioni',
                'details', SQLERRM
            )
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_geo_capoluogos(p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'capoluogo_id'::text, p_sort_order text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_offset integer;
  v_total integer;
  v_data jsonb;
  v_pagination jsonb;
BEGIN
  -- Calcola offset
  v_offset := (p_page - 1) * p_page_size;

  -- Conta totale (con filtri search)
  SELECT COUNT(*)
  INTO v_total
  FROM ana_geo_capoluogo
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(capoluogo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    );

  -- Recupera dati paginati
  SELECT jsonb_agg(
    jsonb_build_object(
      'capoluogo_id', capoluogo_id,
      'capoluogo_descrizione', capoluogo_descrizione
    ) ORDER BY
      CASE WHEN p_sort_order = 'asc' THEN
        CASE p_sort_by
          WHEN 'capoluogo_id' THEN capoluogo_id::text
          WHEN 'capoluogo_descrizione' THEN capoluogo_descrizione::text
        END
      END ASC,
      CASE WHEN p_sort_order = 'desc' THEN
        CASE p_sort_by
          WHEN 'capoluogo_id' THEN capoluogo_id::text
          WHEN 'capoluogo_descrizione' THEN capoluogo_descrizione::text
        END
      END DESC
  )
  INTO v_data
  FROM ana_geo_capoluogo
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(capoluogo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    )
  LIMIT p_page_size
  OFFSET v_offset;

  -- Pagination metadata
  v_pagination := jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'pageSize', p_page_size,
    'totalPages', CEIL(v_total::numeric / p_page_size)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'pagination', v_pagination
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_geo_comunis(p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'comune_id'::text, p_sort_order text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_offset integer;
  v_total integer;
  v_data jsonb;
  v_pagination jsonb;
BEGIN
  -- Calcola offset
  v_offset := (p_page - 1) * p_page_size;

  -- Conta totale (con filtri search)
  SELECT COUNT(*)
  INTO v_total
  FROM ana_geo_comuni r
  LEFT JOIN ana_geo_province g ON r.comune_provincia_fk = g.provincia_id
  LEFT JOIN ana_geo_regioni_ita g3 ON g.regione_id_fk = g3.regione_id
  LEFT JOIN eba_countries g4 ON g3.country_id_fk = g4.country_id
  LEFT JOIN ana_geo_ita_ripgeo g1 ON r.comune_ripgeo_fk = g1.ripgeo_id
  LEFT JOIN ana_geo_capoluogo g2 ON r.comune_capoluogo_fk = g2.capoluogo_id
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(r.comune_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_istat::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_preftel::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_cap::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_codfisc::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g.provincia_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g3.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g4.iso_alpha2::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g1.ripgeo_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g2.capoluogo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    );

  -- Recupera dati paginati con ordinamento multi-colonna
  SELECT jsonb_agg(
    row_to_json(ordered_data)::jsonb
  )
  INTO v_data
  FROM (
    SELECT
      r.comune_id,
      r.comune_descrizione,
      r.comune_istat,
      r.comune_provincia_fk,
      r.comune_preftel,
      r.comune_cap,
      r.comune_codfisc,
      r.comune_num_abitanti,
      r.comune_link,
      r.comune_ripgeo_fk,
      r.comune_capoluogo_fk,
      r.comune_estero,
      g.provincia_descrizione as comune_provincia_name,
      g3.regione_descrizione as comune_regione_name,
      g4.iso_alpha2 as comune_nazione_code,
      g1.ripgeo_descrizione as comune_ripgeo_name,
      g2.capoluogo_descrizione as comune_capoluogo_name
    FROM ana_geo_comuni r
  LEFT JOIN ana_geo_province g ON r.comune_provincia_fk = g.provincia_id
  LEFT JOIN ana_geo_regioni_ita g3 ON g.regione_id_fk = g3.regione_id
  LEFT JOIN eba_countries g4 ON g3.country_id_fk = g4.country_id
  LEFT JOIN ana_geo_ita_ripgeo g1 ON r.comune_ripgeo_fk = g1.ripgeo_id
  LEFT JOIN ana_geo_capoluogo g2 ON r.comune_capoluogo_fk = g2.capoluogo_id
    WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(r.comune_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_istat::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_preftel::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_cap::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.comune_codfisc::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g.provincia_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g3.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g4.iso_alpha2::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g1.ripgeo_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g2.capoluogo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    )
    ORDER BY
      CASE WHEN p_sort_order = 'desc' THEN
        CASE p_sort_by
          WHEN 'comune_id' THEN r.comune_id::text
          WHEN 'comune_descrizione' THEN r.comune_descrizione
          WHEN 'comune_istat' THEN r.comune_istat
          WHEN 'comune_preftel' THEN r.comune_preftel
          WHEN 'comune_cap' THEN r.comune_cap
          WHEN 'comune_codfisc' THEN r.comune_codfisc
          WHEN 'comune_num_abitanti' THEN r.comune_num_abitanti::text
          WHEN 'comune_provincia_name' THEN g.provincia_descrizione
          WHEN 'comune_regione_name' THEN g3.regione_descrizione
          WHEN 'comune_ripgeo_name' THEN g1.ripgeo_descrizione
          WHEN 'comune_capoluogo_name' THEN g2.capoluogo_descrizione
          ELSE r.comune_id::text
        END
      END DESC NULLS LAST,
      CASE WHEN p_sort_order != 'desc' THEN
        CASE p_sort_by
          WHEN 'comune_id' THEN r.comune_id::text
          WHEN 'comune_descrizione' THEN r.comune_descrizione
          WHEN 'comune_istat' THEN r.comune_istat
          WHEN 'comune_preftel' THEN r.comune_preftel
          WHEN 'comune_cap' THEN r.comune_cap
          WHEN 'comune_codfisc' THEN r.comune_codfisc
          WHEN 'comune_num_abitanti' THEN r.comune_num_abitanti::text
          WHEN 'comune_provincia_name' THEN g.provincia_descrizione
          WHEN 'comune_regione_name' THEN g3.regione_descrizione
          WHEN 'comune_ripgeo_name' THEN g1.ripgeo_descrizione
          WHEN 'comune_capoluogo_name' THEN g2.capoluogo_descrizione
          ELSE r.comune_id::text
        END
      END ASC NULLS LAST
    LIMIT p_page_size
    OFFSET v_offset
  ) ordered_data;

  -- Pagination metadata
  v_pagination := jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'pageSize', p_page_size,
    'totalPages', CEIL(v_total::numeric / p_page_size)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'pagination', v_pagination
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_geo_ita_ripgeos(p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'ripgeo_id'::text, p_sort_order text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_offset integer;
  v_total integer;
  v_data jsonb;
  v_pagination jsonb;
BEGIN
  -- Calcola offset
  v_offset := (p_page - 1) * p_page_size;

  -- Conta totale (con filtri search)
  SELECT COUNT(*)
  INTO v_total
  FROM ana_geo_ita_ripgeo
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(ripgeo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    );

  -- Recupera dati paginati
  SELECT jsonb_agg(
    jsonb_build_object(
      'ripgeo_id', ripgeo_id,
      'ripgeo_descrizione', ripgeo_descrizione
    ) ORDER BY
      CASE WHEN p_sort_order = 'asc' THEN
        CASE p_sort_by
          WHEN 'ripgeo_id' THEN ripgeo_id::text
          WHEN 'ripgeo_descrizione' THEN ripgeo_descrizione::text
        END
      END ASC,
      CASE WHEN p_sort_order = 'desc' THEN
        CASE p_sort_by
          WHEN 'ripgeo_id' THEN ripgeo_id::text
          WHEN 'ripgeo_descrizione' THEN ripgeo_descrizione::text
        END
      END DESC
  )
  INTO v_data
  FROM ana_geo_ita_ripgeo
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(ripgeo_descrizione::text) LIKE LOWER('%' || p_search || '%')
    )
  LIMIT p_page_size
  OFFSET v_offset;

  -- Pagination metadata
  v_pagination := jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'pageSize', p_page_size,
    'totalPages', CEIL(v_total::numeric / p_page_size)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'pagination', v_pagination
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_geo_provinces(p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'provincia_id'::text, p_sort_order text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_offset integer;
  v_total integer;
  v_data jsonb;
  v_pagination jsonb;
BEGIN
  -- Calcola offset
  v_offset := (p_page - 1) * p_page_size;

  -- Conta totale (con filtri search)
  SELECT COUNT(*)
  INTO v_total
  FROM ana_geo_province r
  LEFT JOIN ana_geo_regioni_ita g ON r.regione_id_fk = g.regione_id
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(r.provincia_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(r.provincia_sigla::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(g.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
    );

  -- Recupera dati paginati con ordinamento multi-colonna
  -- Default: regione_name ASC, provincia_descrizione ASC
  SELECT jsonb_agg(
    row_to_json(ordered_data)::jsonb
  )
  INTO v_data
  FROM (
    SELECT
      r.provincia_id,
      r.provincia_descrizione,
      r.provincia_sigla,
      r.provincia_superficie,
      r.provincia_residenti,
      r.provincia_num_comuni,
      r.regione_id_fk,
      g.regione_descrizione as regione_name
    FROM ana_geo_province r
    LEFT JOIN ana_geo_regioni_ita g ON r.regione_id_fk = g.regione_id
    WHERE 1=1
      AND (
        p_search IS NULL
        OR LOWER(r.provincia_descrizione::text) LIKE LOWER('%' || p_search || '%')
        OR LOWER(r.provincia_sigla::text) LIKE LOWER('%' || p_search || '%')
        OR LOWER(g.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
      )
    ORDER BY
      -- Always sort by regione_name first, then provincia_descrizione
      g.regione_descrizione ASC NULLS LAST,
      r.provincia_descrizione ASC NULLS LAST
    LIMIT p_page_size
    OFFSET v_offset
  ) ordered_data;

  -- Pagination metadata
  v_pagination := jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'pageSize', p_page_size,
    'totalPages', CEIL(v_total::numeric / p_page_size)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'pagination', v_pagination
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_all_geo_regioni_itas(p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'regione_id'::text, p_sort_order text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_offset integer;
  v_total integer;
  v_data jsonb;
  v_pagination jsonb;
BEGIN
  -- Calcola offset
  v_offset := (p_page - 1) * p_page_size;

  -- Conta totale (con filtri search e JOIN per ricerca su nazione)
  SELECT COUNT(*)
  INTO v_total
  FROM ana_geo_regioni_ita r
  LEFT JOIN eba_countries c ON r.country_id_fk = c.country_id
  WHERE 1=1
    AND (
      p_search IS NULL
      OR LOWER(r.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
      OR LOWER(c.name::text) LIKE LOWER('%' || p_search || '%')
    );

  -- Recupera dati paginati con ordinamento multi-colonna
  -- Default: country_name ASC, regione_descrizione ASC
  SELECT jsonb_agg(
    row_to_json(ordered_data)::jsonb
  )
  INTO v_data
  FROM (
    SELECT
      r.regione_id,
      r.country_id_fk,
      c.name as country_name,
      r.regione_descrizione,
      r.regione_nr_residenti,
      r.regione_perc_residenti,
      r.regione_densita_kmq,
      r.regione_nr_province,
      r.regione_nr_comuni
    FROM ana_geo_regioni_ita r
    LEFT JOIN eba_countries c ON r.country_id_fk = c.country_id
    WHERE 1=1
      AND (
        p_search IS NULL
        OR LOWER(r.regione_descrizione::text) LIKE LOWER('%' || p_search || '%')
        OR LOWER(c.name::text) LIKE LOWER('%' || p_search || '%')
      )
    ORDER BY
      -- ⭐ Ordinamento multi-colonna FISSO
      -- Prima per nazione, poi per regione all'interno di ogni nazione
      c.name ASC NULLS LAST,
      r.regione_descrizione ASC NULLS LAST
    LIMIT p_page_size
    OFFSET v_offset
  ) ordered_data;

  -- Pagination metadata
  v_pagination := jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'pageSize', p_page_size,
    'totalPages', CEIL(v_total::numeric / p_page_size)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'pagination', v_pagination
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_azienda_by_id(p_azienda_id integer DEFAULT NULL::integer, p_tenant_id character varying DEFAULT NULL::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result record;
    v_response jsonb;
BEGIN
    -- Validazione parametri
    IF p_azienda_id IS NULL AND p_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'INVALID_INPUT',
            'detail', 'Specificare azienda_id o tenant_id'
        );
    END IF;
    
    -- Query principale
    SELECT 
        azienda_id,
        tenant_id,
        ragione_sociale,
        forma_giuridica,
        data_costituzione,
        data_inizio_attivita,
        capitale_sociale,
        socio_unico,
        in_liquidazione,
        partita_iva,
        codice_fiscale,
        rea_provincia_fk,
        rea_numero,
        rea_data_iscrizione,
        codice_destinatario_sdi,
        pec,
        sito_web,
        telefono_principale,
        attivo,
        data_creazione,
        data_ultima_modifica
    INTO v_result
    FROM public.ana_aziende 
    WHERE (p_azienda_id IS NULL OR azienda_id = p_azienda_id)
    AND (p_tenant_id IS NULL OR tenant_id = p_tenant_id);
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AZIENDA_NOT_FOUND',
            'detail', 'Azienda non trovata'
        );
    END IF;
    
    -- Costruzione risposta
    v_response := jsonb_build_object(
        'success', true,
        'data', row_to_json(v_result)::jsonb
    );
    
    RETURN v_response;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'DATABASE_ERROR',
            'detail', SQLERRM
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_azienda_by_id(p_azienda_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_azienda RECORD;
BEGIN
  SELECT * INTO v_azienda FROM public.ana_aziende WHERE azienda_id = p_azienda_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'AZIENDA_NOT_FOUND');
  END IF;
  RETURN jsonb_build_object('success', true, 'azienda', row_to_json(v_azienda));
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_aziende_distinct_values(p_column_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_query text;
    v_result jsonb[];
    v_record record;
BEGIN
    -- Validazione colonna
    IF p_column_name NOT IN ('forma_giuridica', 'rea_provincia_fk', 'attivo', 'socio_unico', 'in_liquidazione') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'INVALID_COLUMN',
            'detail', 'Colonna non valida per filtri'
        );
    END IF;
    
    -- Costruzione query dinamica
    v_query := '
        SELECT 
            ' || p_column_name || ' as value,
            COUNT(*) as count
        FROM public.ana_aziende 
        WHERE ' || p_column_name || ' IS NOT NULL
        GROUP BY ' || p_column_name || '
        ORDER BY count DESC, ' || p_column_name;
    
    -- Esecuzione e costruzione risultati
    v_result := ARRAY[]::jsonb[];
    FOR v_record IN EXECUTE v_query LOOP
        v_result := array_append(v_result, jsonb_build_object(
            'value', v_record.value,
            'count', v_record.count,
            'label', v_record.value
        ));
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'columnName', p_column_name,
        'data', array_to_json(v_result)::jsonb
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'DATABASE_ERROR',
            'detail', SQLERRM
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_comune_by_id(p_comune_id integer)
 RETURNS TABLE(comune_id integer, comune_formatted text, comune_cap character varying, comune_descrizione character varying, provincia_sigla character, provincia_descrizione character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT 
        c.comune_id,
        CASE 
            WHEN c.comune_id IS NOT NULL THEN 
                CONCAT(c.comune_cap, ' - ', UPPER(c.comune_descrizione), ' (', p.provincia_sigla, ')')
            ELSE NULL 
        END as comune_formatted,
        c.comune_cap,
        c.comune_descrizione,
        p.provincia_sigla,
        p.provincia_descrizione
    FROM ana_geo_comuni c
    LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
    WHERE c.comune_id = p_comune_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_comune_formatted(p_comune_id integer)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  SELECT CASE 
    WHEN c.comune_id IS NOT NULL THEN 
      CONCAT(c.comune_cap, ' - ', UPPER(c.comune_descrizione), ' (', p.provincia_sigla, ')')
    ELSE NULL 
  END
  FROM ana_geo_comuni c
  LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
  WHERE c.comune_id = p_comune_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_comuni_lookup(p_search_term text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(comune_id integer, comune_formatted text, comune_descrizione character varying, comune_cap character varying, provincia_sigla character varying)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  SELECT 
    c.comune_id,
    CONCAT(c.comune_cap, ' - ', UPPER(c.comune_descrizione), ' (', p.provincia_sigla, ')') as comune_formatted,
    c.comune_descrizione,
    c.comune_cap,
    p.provincia_sigla
  FROM ana_geo_comuni c
  LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
  WHERE (
    p_search_term IS NULL OR 
    UPPER(c.comune_descrizione) LIKE UPPER('%' || p_search_term || '%') OR
    c.comune_cap LIKE '%' || p_search_term || '%' OR
    UPPER(p.provincia_sigla) LIKE UPPER('%' || p_search_term || '%')
  )
  ORDER BY c.comune_descrizione
  LIMIT p_limit;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_by_id(p_country_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    -- Validazione parametri
    IF p_country_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'MISSING_COUNTRY_ID',
                'message', 'ID nazione obbligatorio',
                'field', 'country_id'
            )
        );
    END IF;

    -- Recupera nazione con JOIN a eba_country_organizations
    SELECT jsonb_build_object(
        'country_id', c.country_id,
        'name', c.name,
        'nationality', c.nationality,
        'country_code', c.country_code,
        'iso_alpha2', c.iso_alpha2,
        'capital', c.capital,
        'population', c.population,
        'area_km2', c.area_km2,
        'region_id', c.region_id,
        'sub_region_id', c.sub_region_id,
        'intermediate_region_id', c.intermediate_region_id,
        'organization_region_id', c.organization_region_id,
        'organization_name', org.name
    )
    INTO v_result
    FROM eba_countries c
    LEFT JOIN eba_country_organizations org ON org.id = c.organization_region_id
    WHERE c.country_id = p_country_id;

    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'COUNTRY_NOT_FOUND',
                'message', 'Nazione non trovata',
                'field', 'country_id'
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_result
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'DATABASE_ERROR',
                'message', 'Errore durante il recupero della nazione',
                'details', SQLERRM
            )
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_intermediate_by_id(p_intermediate_id integer)
 RETURNS TABLE(id integer, name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        ir.id,
        ir.name::TEXT
    FROM eba_country_intermediates ir
    WHERE ir.id = p_intermediate_id;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_intermediates_lookup()
 RETURNS TABLE(value integer, label character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id AS value,
        ci.name AS label
    FROM eba_country_intermediates ci
    ORDER BY ci.name;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_organization_by_id(p_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    -- Validazione parametri
    IF p_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'MISSING_ID',
                'message', 'ID organizzazione obbligatorio',
                'field', 'id'
            )
        );
    END IF;

    -- Recupera organizzazione
    SELECT jsonb_build_object(
        'id', id,
        'code', code,
        'name', name
    )
    INTO v_result
    FROM eba_country_organizations
    WHERE id = p_id;

    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'ORGANIZATION_NOT_FOUND',
                'message', 'Organizzazione non trovata',
                'field', 'id'
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_result
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', jsonb_build_object(
                'code', 'DATABASE_ERROR',
                'message', 'Errore durante il recupero dell''organizzazione',
                'details', SQLERRM
            )
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_organizations_lookup()
 RETURNS TABLE(value integer, label character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        co.id AS value,
        co.name AS label
    FROM eba_country_organizations co
    ORDER BY co.name;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_region_by_id(p_region_id integer)
 RETURNS TABLE(id integer, name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.name::TEXT
    FROM eba_country_regions r
    WHERE r.id = p_region_id;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_regions_lookup()
 RETURNS TABLE(value integer, label character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id AS value,
        r.name AS label
    FROM eba_country_regions r
    ORDER BY r.name;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_sub_region_by_id(p_sub_region_id integer)
 RETURNS TABLE(id integer, name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        sr.id,
        sr.name::TEXT
    FROM eba_country_sub_regions sr
    WHERE sr.id = p_sub_region_id;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_country_sub_regions_lookup()
 RETURNS TABLE(value integer, label character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id AS value,
        sr.name AS label
    FROM eba_country_sub_regions sr
    ORDER BY sr.name;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_capoluogo(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_record record;
BEGIN
  SELECT capoluogo_id, capoluogo_descrizione
  INTO v_record
  FROM ana_geo_capoluogo
  WHERE capoluogo_id = p_id::integer;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', row_to_json(v_record)::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_capoluogos_lookup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_data jsonb;
  v_total integer;
BEGIN
  -- Conta totale
  SELECT COUNT(*) INTO v_total
  FROM ana_geo_capoluogo;

  -- Recupera dati in formato {value, label}
  -- IMPORTANTE: value deve essere ::text per React keys
  SELECT jsonb_agg(
    jsonb_build_object(
      'value', capoluogo_id::text,
      'label', capoluogo_descrizione
    ) ORDER BY capoluogo_descrizione
  )
  INTO v_data
  FROM ana_geo_capoluogo;

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'total', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_comuni(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'comune_id', r.comune_id,
      'comune_descrizione', r.comune_descrizione,
      'comune_istat', r.comune_istat,
      'comune_provincia_fk', r.comune_provincia_fk,
      'comune_preftel', r.comune_preftel,
      'comune_cap', r.comune_cap,
      'comune_codfisc', r.comune_codfisc,
      'comune_num_abitanti', r.comune_num_abitanti,
      'comune_link', r.comune_link,
      'comune_ripgeo_fk', r.comune_ripgeo_fk,
      'comune_capoluogo_fk', r.comune_capoluogo_fk,
      'comune_estero', r.comune_estero,
      'comune_provincia_name', g.provincia_descrizione,
      'comune_regione_name', g3.regione_descrizione,
      'comune_nazione_code', g4.iso_alpha2,
      'comune_ripgeo_name', g1.ripgeo_descrizione,
      'comune_capoluogo_name', g2.capoluogo_descrizione
  )
  INTO v_result
  FROM ana_geo_comuni r
  LEFT JOIN ana_geo_province g ON r.comune_provincia_fk = g.provincia_id
  LEFT JOIN ana_geo_regioni_ita g3 ON g.regione_id_fk = g3.regione_id
  LEFT JOIN eba_countries g4 ON g3.country_id_fk = g4.country_id
  LEFT JOIN ana_geo_ita_ripgeo g1 ON r.comune_ripgeo_fk = g1.ripgeo_id
  LEFT JOIN ana_geo_capoluogo g2 ON r.comune_capoluogo_fk = g2.capoluogo_id
  WHERE r.comune_id = p_id::integer;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', v_result
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_comunis_lookup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_data jsonb;
  v_total integer;
BEGIN
  SELECT COUNT(*) INTO v_total FROM ana_geo_comuni;

  SELECT jsonb_agg(
    jsonb_build_object(
      'value', comune_id::text,
      'label', comune_descrizione
    ) ORDER BY comune_descrizione
  )
  INTO v_data
  FROM ana_geo_comuni;

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'total', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_ita_ripgeo(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_record record;
BEGIN
  SELECT ripgeo_id, ripgeo_descrizione
  INTO v_record
  FROM ana_geo_ita_ripgeo
  WHERE ripgeo_id = p_id::integer;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', row_to_json(v_record)::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_ita_ripgeos_lookup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_data jsonb;
  v_total integer;
BEGIN
  SELECT COUNT(*) INTO v_total FROM ana_geo_ita_ripgeo;

  SELECT jsonb_agg(
    jsonb_build_object(
      'value', ripgeo_id::text,
      'label', ripgeo_descrizione
    ) ORDER BY ripgeo_descrizione
  )
  INTO v_data
  FROM ana_geo_ita_ripgeo;

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'total', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_province(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'provincia_id', r.provincia_id,
      'provincia_descrizione', r.provincia_descrizione,
      'provincia_sigla', r.provincia_sigla,
      'provincia_superficie', r.provincia_superficie,
      'provincia_residenti', r.provincia_residenti,
      'provincia_num_comuni', r.provincia_num_comuni,
      'regione_id_fk', r.regione_id_fk,
      'regione_name', g.regione_descrizione
  )
  INTO v_result
  FROM ana_geo_province r
  LEFT JOIN ana_geo_regioni_ita g ON r.regione_id_fk = g.regione_id
  WHERE r.provincia_id = p_id::integer;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', v_result
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_provinces_lookup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_data jsonb;
  v_total integer;
BEGIN
  SELECT COUNT(*) INTO v_total FROM ana_geo_province;

  SELECT jsonb_agg(
    jsonb_build_object(
      'value', provincia_id::text,
      'label', provincia_descrizione
    ) ORDER BY provincia_descrizione
  )
  INTO v_data
  FROM ana_geo_province;

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'total', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_regioni_ita(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_record record;
BEGIN
  SELECT r.regione_id, r.country_id_fk, c.name as country_name, r.regione_descrizione, r.regione_nr_residenti, r.regione_perc_residenti, r.regione_densita_kmq, r.regione_nr_province, r.regione_nr_comuni
  INTO v_record
  FROM ana_geo_regioni_ita r
  LEFT JOIN eba_countries c ON r.country_id_fk = c.country_id
  WHERE r.regione_id = p_id::integer;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', row_to_json(v_record)::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_geo_regioni_itas_lookup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_data jsonb;
  v_total integer;
BEGIN
  SELECT COUNT(*) INTO v_total FROM ana_geo_regioni_ita;

  SELECT jsonb_agg(
    jsonb_build_object(
      'value', regione_id::text,
      'label', regione_descrizione
    ) ORDER BY regione_descrizione
  )
  INTO v_data
  FROM ana_geo_regioni_ita;

  RETURN jsonb_build_object(
    'success', true,
    'data', COALESCE(v_data, '[]'::jsonb),
    'total', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_get_tipo_sede_by_id(p_tipo_sede_id integer)
 RETURNS TABLE(tipo_sede_id integer, codice character varying, descrizione character varying, is_active boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT 
        ts.tipo_sede_id,
        ts.codice,
        ts.descrizione,
        ts.is_active
    FROM ana_tipo_sedi ts
    WHERE ts.tipo_sede_id = p_tipo_sede_id
        AND ts.is_active = true;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_login_text_debug(p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_hash_from_db text;
  v_computed_hash text;
BEGIN
  -- Ottieni l'hash dal database
  SELECT password_hash INTO v_hash_from_db 
  FROM app_users 
  WHERE email = p_email::citext;
  
  -- Calcola l'hash della password ricevuta
  SELECT crypt(p_password, v_hash_from_db) INTO v_computed_hash;
  
  -- Ritorna info di debug
  RETURN jsonb_build_object(
    'received_email', p_email,
    'received_password', p_password,
    'password_length', length(p_password),
    'hash_from_db', v_hash_from_db,
    'computed_hash', v_computed_hash,
    'match', (v_computed_hash = v_hash_from_db)
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_logo_create_backup_20250909(p_tenant_id character varying, p_azienda_fk integer, p_logo_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Funzione di backup - NON MODIFICARE
  RETURN jsonb_build_object('success', false, 'error', 'BACKUP_FUNCTION');
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_app_profile(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
BEGIN
  SELECT u.user_id, u.email, u.nome, u.cognome, u.last_login_at,
         m.role_code, r.role_name, m.azienda_id
    INTO v_user
  FROM public.app_users u
  LEFT JOIN public.app_user_role_map m ON m.user_id = u.user_id
  LEFT JOIN public.user_roles r        ON r.role_code = m.role_code
  WHERE u.user_id = p_user_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user', jsonb_build_object(
      'user_id',       v_user.user_id,
      'tenant_id',     '',
      'email',         v_user.email,
      'nome',          v_user.nome,
      'cognome',       v_user.cognome,
      'role_code',     v_user.role_code,
      'role_name',     v_user.role_name,
      'azienda_id',    v_user.azienda_id,
      'last_login_at', v_user.last_login_at
    )
  );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_exists_cliente_anagrafica(p_cognome character varying, p_nome character varying, p_data_nascita date, p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE UPPER(cliente_cognome) = UPPER(p_cognome)
          AND UPPER(cliente_nome) = UPPER(p_nome)
          AND cliente_data_nascita = p_data_nascita
          AND UPPER(cliente_codicefiscale) = UPPER(p_codice_fiscale)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_exists_cliente_codice_fiscale(p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE UPPER(cliente_codicefiscale) = UPPER(p_codice_fiscale)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_exists_cliente_email(p_email character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE LOWER(cliente_email) = LOWER(p_email)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_debug_v2(p_azienda_id integer)
 RETURNS TABLE(transazione_id integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.transazione_id,
        t.transazione_aliquota_iva_fk,
        t.transazione_imponibile_eur,
        t.transazione_iva_eur,
        t.transazione_lordo_eur,
        t.transazione_iva_modalita_input,
        t.transazione_tasso_cambio_applicato,
        t.transazione_tasso_fonte,
        t.transazione_tasso_data_validita
    FROM mov_transazioni t
    JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    LEFT JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE t.transazione_azienda_id = p_azienda_id
    LIMIT 1;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_logo_field_help(field_name text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN CASE field_name
        WHEN 'file_format' THEN 'Formati supportati: SVG (vettoriale), PNG (trasparente), WebP (moderno), JPEG/JPG (fotografico), EPS (stampa), GIF (animato)'
        WHEN 'file_size_bytes' THEN 'Dimensione massima consentita: 10 MB. Per file più grandi, utilizzare formati vettoriali come SVG'
        WHEN 'alt_text' THEN 'Descrizione alternativa per l''accessibilità. Massimo 500 caratteri. Es: "Logo aziendale su sfondo bianco"'
        WHEN 'usage_context' THEN 'Contesti dove verrà utilizzato il logo: web, stampa, email, social media, documenti, presentazioni, mobile, desktop'
        WHEN 'logo_type' THEN 'Tipo di logo: primary (principale), secondary (secondario), watermark (filigrana), favicon (icona browser), letterhead (intestazione)'
        WHEN 'logo_variant' THEN 'Variante del logo: standard, horizontal (orizzontale), vertical (verticale), icon (solo icona), monochrome (monocromatico), inverse (invertito)'
        WHEN 'priority' THEN 'Priorità di utilizzo (numero più alto = priorità maggiore). Default: 1'
        WHEN 'compression_quality' THEN 'Qualità compressione per JPEG (1-100). Raccomandato: 85-95 per web, 100 per stampa'
        WHEN 'dpi' THEN 'Risoluzione in DPI. Web: 72-96 DPI, Stampa: 300+ DPI'
        WHEN 'is_web_optimized' THEN 'Ottimizzazione web disponibile solo per PNG, WebP, JPEG. Riduce dimensioni mantenendo qualità'
        ELSE 'Campo non riconosciuto'
    END;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_menu_breadcrumbs(p_menu_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
    WITH RECURSIVE breadcrumb_path AS (
        -- Menu corrente
        SELECT
            menu_id, parent_id, menu_name, menu_level, route_path,
            1 as depth
        FROM sys_menu_items
        WHERE menu_id = p_menu_id
          AND is_active = true

        UNION ALL

        -- Risali la gerarchia
        SELECT
            m.menu_id, m.parent_id, m.menu_name, m.menu_level, m.route_path,
            bp.depth + 1
        FROM sys_menu_items m
        INNER JOIN breadcrumb_path bp ON bp.parent_id = m.menu_id
        WHERE m.is_active = true
          AND bp.depth < 10  -- Protezione loop infiniti
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'menu_id', menu_id,
            'name', menu_name,
            'level', menu_level,
            'route', route_path
        ) ORDER BY depth DESC
    )
    FROM breadcrumb_path;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_transazioni_per_stampa(p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_tipo_movimento character varying DEFAULT NULL::character varying, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'DATA_DOCUMENTO'::character varying)
 RETURNS TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_tipo_movimento character varying, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_data_documento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_fattura_fk integer, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.transazione_id,
        t.transazione_azienda_id,
        t.transazione_viaggio_id,
        t.transazione_data_viaggio_id,
        t.transazione_controparte_id,
        t.transazione_tipo_movimento,
        t.transazione_importo,
        t.transazione_valuta_id,
        t.transazione_importo_eur,
        t.transazione_data,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        t.transazione_data_documento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_note,
        t.transazione_numero_documento,
        t.transazione_fattura_fk,
        a.azienda_codice::TEXT,
        c.ragione_sociale as controparte_ragione_sociale,
        v.valuta_codice_iso,
        vi.viaggio_descrizione_breve,
        dv.data_viaggio_data_inizio
    FROM mov_transazioni t
    LEFT JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
    LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE
        (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
        AND (p_controparte_id IS NULL OR t.transazione_controparte_id = p_controparte_id)
        AND (p_tipo_movimento IS NULL OR t.transazione_tipo_movimento = p_tipo_movimento)
        AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
        AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
        AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
        AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
        AND (p_data_transazione_da IS NULL OR t.transazione_data >= p_data_transazione_da)
        AND (p_data_transazione_a IS NULL OR t.transazione_data <= p_data_transazione_a)
        AND (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da)
        AND (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a)
        AND (p_importo_da IS NULL OR t.transazione_importo >= p_importo_da)
        AND (p_importo_a IS NULL OR t.transazione_importo <= p_importo_a)
        AND (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%')
        AND (NOT p_solo_con_documento OR (t.transazione_numero_documento IS NOT NULL AND t.transazione_data_documento IS NOT NULL))
        AND (NOT p_solo_scadute OR (t.transazione_data_scadenza < CURRENT_DATE AND t.transazione_stato = 'DA_PAGARE'))
        AND (NOT p_solo_con_viaggio OR t.transazione_viaggio_id IS NOT NULL)
        AND (NOT p_solo_senza_viaggio OR t.transazione_viaggio_id IS NULL)
        AND (NOT p_solo_con_fattura OR t.transazione_fattura_fk IS NOT NULL)
    ORDER BY
        CASE WHEN p_ordinamento = 'FORNITORE' THEN c.ragione_sociale END,
        CASE WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN t.transazione_data_documento END,
        CASE WHEN p_ordinamento = 'IMPORTO_ASC' THEN t.transazione_importo END ASC,
        CASE WHEN p_ordinamento = 'IMPORTO_DESC' THEN t.transazione_importo END DESC,
        CASE WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN t.transazione_tipo_movimento END;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_logo_calculate_hash(p_binary_data bytea)
 RETURNS character varying
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$
BEGIN
    IF p_binary_data IS NULL OR length(p_binary_data) = 0 THEN
        RAISE EXCEPTION 'INVALID_BINARY_DATA: Dati binari non validi o vuoti';
    END IF;
    RETURN encode(digest(p_binary_data, 'sha256'), 'hex');
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_logo_setup_master_detail_relation()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_relation_id uuid;
    v_field_config_ids uuid[];
BEGIN
    -- Inserisci o aggiorna relazione master-detail
    INSERT INTO master_detail_relations (
        master_table, detail_table, relation_name,
        master_key_column, detail_key_column, foreign_key_column,
        display_column, order_column, order_direction,
        detail_label_singular, detail_label_plural,
        icon_name, color_scheme, is_required, max_records,
        allow_duplicates, cascade_delete, is_active,
        supports_inline_edit, supports_modal_edit, supports_bulk_operations,
        nesting_level
    ) VALUES (
        'ana_aziende', 'ana_aziende_logo', 'aziende_logo',
        'azienda_id', 'logo_id', 'azienda_fk',
        'file_name', 'priority', 'ASC',
        'Logo', 'Logo',
        'Image', 'purple', false, NULL,
        true, true, true,
        true, true, false,
        1
    )
    ON CONFLICT (master_table, detail_table, relation_name)
    DO UPDATE SET
        display_column = EXCLUDED.display_column,
        order_column = EXCLUDED.order_column,
        order_direction = EXCLUDED.order_direction,
        is_active = true,
        updated_at = now()
    RETURNING relation_id INTO v_relation_id;

    -- Configurazioni campi principali
    INSERT INTO master_detail_field_config (
        relation_id, column_name, field_type, label,
        is_required, field_order, is_visible, show_in_grid
    ) VALUES 
    (v_relation_id, 'logo_type', 'select', 'Tipo Logo', true, 1, true, true),
    (v_relation_id, 'logo_variant', 'select', 'Variante', false, 2, true, true),
    (v_relation_id, 'file_name', 'text', 'Nome File', true, 3, true, true),
    (v_relation_id, 'alt_text', 'text', 'Testo Alternativo', true, 4, true, false),
    (v_relation_id, 'description', 'textarea', 'Descrizione', false, 5, true, false),
    (v_relation_id, 'is_default', 'boolean', 'Predefinito', false, 6, true, true),
    (v_relation_id, 'priority', 'number', 'Priorità', false, 7, true, true),
    (v_relation_id, 'usage_context', 'select', 'Contesti d''uso', false, 8, true, false)
    ON CONFLICT (relation_id, column_name) 
    DO UPDATE SET
        label = EXCLUDED.label,
        field_order = EXCLUDED.field_order,
        is_visible = EXCLUDED.is_visible,
        updated_at = now();

    -- Opzioni per campo logo_type
    UPDATE master_detail_field_config 
    SET select_options = jsonb_build_object(
        'type', 'static',
        'options', jsonb_build_array(
            jsonb_build_object('value', 'primary', 'label', 'Principale'),
            jsonb_build_object('value', 'secondary', 'label', 'Secondario'),
            jsonb_build_object('value', 'watermark', 'label', 'Watermark'),
            jsonb_build_object('value', 'favicon', 'label', 'Favicon'),
            jsonb_build_object('value', 'letterhead', 'label', 'Intestazione'),
            jsonb_build_object('value', 'social', 'label', 'Social Media')
        )
    )
    WHERE relation_id = v_relation_id AND column_name = 'logo_type';

    -- Opzioni per campo logo_variant
    UPDATE master_detail_field_config 
    SET select_options = jsonb_build_object(
        'type', 'static',
        'options', jsonb_build_array(
            jsonb_build_object('value', 'standard', 'label', 'Standard'),
            jsonb_build_object('value', 'horizontal', 'label', 'Orizzontale'),
            jsonb_build_object('value', 'vertical', 'label', 'Verticale'),
            jsonb_build_object('value', 'icon', 'label', 'Icona'),
            jsonb_build_object('value', 'monochrome', 'label', 'Monocromatico'),
            jsonb_build_object('value', 'inverse', 'label', 'Inverso'),
            jsonb_build_object('value', 'dark', 'label', 'Scuro'),
            jsonb_build_object('value', 'light', 'label', 'Chiaro')
        )
    )
    WHERE relation_id = v_relation_id AND column_name = 'logo_variant';

    -- Opzioni per campo usage_context
    UPDATE master_detail_field_config 
    SET select_options = jsonb_build_object(
        'type', 'static',
        'multiple', true,
        'options', jsonb_build_array(
            jsonb_build_object('value', 'web', 'label', 'Web'),
            jsonb_build_object('value', 'print', 'label', 'Stampa'),
            jsonb_build_object('value', 'email', 'label', 'Email'),
            jsonb_build_object('value', 'social', 'label', 'Social Media'),
            jsonb_build_object('value', 'document', 'label', 'Documenti'),
            jsonb_build_object('value', 'presentation', 'label', 'Presentazioni'),
            jsonb_build_object('value', 'mobile', 'label', 'Mobile'),
            jsonb_build_object('value', 'desktop', 'label', 'Desktop')
        )
    )
    WHERE relation_id = v_relation_id AND column_name = 'usage_context';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Configurazione master-detail per ana_aziende_logo completata',
        'data', jsonb_build_object(
            'relation_id', v_relation_id,
            'configured_fields', 8
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'CONFIGURATION_ERROR',
            'message', 'Errore durante la configurazione master-detail: ' || SQLERRM
        );
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_logo_update_access_stats(p_logo_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE ana_aziende_logo 
    SET 
        last_accessed = now(),
        access_count = access_count + 1
    WHERE logo_id = p_logo_id;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_logo_validate_mime_type(p_file_format character varying, p_mime_type character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$
BEGIN
    RETURN CASE 
        WHEN p_file_format = 'svg' AND p_mime_type = 'image/svg+xml' THEN true
        WHEN p_file_format = 'png' AND p_mime_type = 'image/png' THEN true
        WHEN p_file_format = 'webp' AND p_mime_type = 'image/webp' THEN true
        WHEN p_file_format IN ('jpeg', 'jpg') AND p_mime_type = 'image/jpeg' THEN true
        WHEN p_file_format = 'gif' AND p_mime_type = 'image/gif' THEN true
        WHEN p_file_format = 'eps' AND p_mime_type = 'application/postscript' THEN true
        ELSE false
    END;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_test_smtp_config(p_smtp_id uuid)
 RETURNS TABLE(success boolean, message text, response_time interval)
 LANGUAGE plpgsql
AS $function$
DECLARE
    config_record ana_aziende_smtp%ROWTYPE;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    start_time := clock_timestamp();
    
    SELECT * INTO config_record FROM ana_aziende_smtp WHERE smtp_id = p_smtp_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'SMTP configuration not found', NULL::INTERVAL;
        RETURN;
    END IF;
    
    -- Basic validation checks
    IF config_record.status != 'active' THEN
        RETURN QUERY SELECT false, 'SMTP configuration is not active', NULL::INTERVAL;
        RETURN;
    END IF;
    
    -- Simulate test (in real implementation, this would connect to SMTP server)
    PERFORM pg_sleep(0.1); -- Simulate network delay
    end_time := clock_timestamp();
    
    -- Update test results
    UPDATE ana_aziende_smtp 
    SET last_test_date = NOW(),
        last_test_result = 'success',
        last_error_message = NULL
    WHERE smtp_id = p_smtp_id;
    
    RETURN QUERY SELECT true, 'SMTP test successful', end_time - start_time;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trip_dates(p_azienda_id integer, p_viaggio_id integer)
 RETURNS TABLE(data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date)
 LANGUAGE plpgsql
AS $function$
        BEGIN
            RETURN QUERY
            SELECT 
                d.data_viaggio_id,
                d.data_viaggio_data_inizio,
                d.data_viaggio_data_fine
            FROM ana_date_viaggi d
            WHERE d.azienda_id = p_azienda_id 
              AND d.viaggio_id_fk = p_viaggio_id
              AND d.data_viaggio_data_inizio > CURRENT_DATE
              AND d.data_viaggio_effettuato_sino = 'N'
            ORDER BY d.data_viaggio_data_inizio ASC;
        END;
        $function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trip_details(p_azienda_id integer, p_viaggio_id integer)
 RETURNS TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_numero_giorni integer, nome_nazione character varying, viaggio_tipo_pernottamento_fk integer, ana_tipo_pernottamento_con_albergo character varying)
 LANGUAGE plpgsql
AS $function$
            BEGIN
                RETURN QUERY
                SELECT 
                    v.viaggio_id,
                    v.viaggio_descrizione_breve,
                    v.viaggio_numero_giorni,
                    c.name::VARCHAR,
                    v.viaggio_tipo_pernottamento_fk,
                    p.ana_tipo_pernottamento_con_albergo::VARCHAR -- CAST ESPLICITO A VARCHAR
                FROM ana_viaggi v
                JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
                LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
                WHERE v.azienda_id = p_azienda_id AND v.viaggio_id = p_viaggio_id;
            END;
            $function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trips_available(p_azienda_id integer)
 RETURNS TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_numero_giorni integer, nome_nazione character varying)
 LANGUAGE plpgsql
AS $function$
            BEGIN
                RETURN QUERY
                SELECT 
                    v.viaggio_id,
                    v.viaggio_descrizione_breve::VARCHAR,
                    v.viaggio_numero_giorni,
                    c.name::VARCHAR
                FROM ana_viaggi v
                JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
                WHERE v.azienda_id = p_azienda_id
                  AND EXISTS (
                      SELECT 1 
                      FROM ana_date_viaggi d 
                      WHERE d.viaggio_id_fk = v.viaggio_id 
                        AND d.azienda_id = v.azienda_id
                        AND d.data_viaggio_data_inizio > CURRENT_DATE
                        AND d.data_viaggio_effettuato_sino = 'N'
                  )
                ORDER BY (
                    SELECT MIN(d2.data_viaggio_data_inizio)
                    FROM ana_date_viaggi d2
                    WHERE d2.viaggio_id_fk = v.viaggio_id
                      AND d2.azienda_id = v.azienda_id
                      AND d2.data_viaggio_data_inizio > CURRENT_DATE
                      AND d2.data_viaggio_effettuato_sino = 'N'
                ) ASC, v.viaggio_descrizione_breve ASC;
            END;
            $function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validate_config_type_requirements(p_config_type character varying, p_from_email text, p_host character varying, p_port integer, p_username character varying)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_error_msg TEXT := '';
BEGIN
    CASE p_config_type
        WHEN 'main' THEN
            IF p_from_email IS NULL OR TRIM(p_from_email) = '' THEN
                v_error_msg := 'La configurazione principale deve specificare un indirizzo email mittente';
            ELSIF p_host IS NULL OR TRIM(p_host) = '' THEN
                v_error_msg := 'La configurazione principale deve specificare un server SMTP';
            ELSIF p_port IS NULL THEN
                v_error_msg := 'La configurazione principale deve specificare una porta SMTP';
            END IF;
            
        WHEN 'pec' THEN
            IF p_from_email IS NULL OR TRIM(p_from_email) = '' THEN
                v_error_msg := 'La configurazione PEC deve specificare un indirizzo email certificato';
            ELSIF NOT fn_is_pec_domain(p_from_email) THEN
                v_error_msg := 'Per le configurazioni PEC è necessario utilizzare un dominio certificato (.pec. o .postacert.)';
            ELSIF p_host IS NULL OR TRIM(p_host) = '' THEN
                v_error_msg := 'La configurazione PEC deve specificare un server SMTP certificato';
            END IF;
            
        WHEN 'support' THEN
            IF p_from_email IS NULL OR TRIM(p_from_email) = '' THEN
                v_error_msg := 'La configurazione supporto deve specificare un indirizzo email di supporto';
            ELSIF p_from_email !~* '(support|supporto|aiuto|assistenza)' THEN
                v_error_msg := 'L''indirizzo email per il supporto dovrebbe contenere termini come "support", "supporto", "aiuto" o "assistenza"';
            END IF;
            
        WHEN 'marketing' THEN
            IF p_from_email IS NULL OR TRIM(p_from_email) = '' THEN
                v_error_msg := 'La configurazione marketing deve specificare un indirizzo email per le comunicazioni';
            END IF;
            
        WHEN 'noreply' THEN
            IF p_from_email IS NULL OR TRIM(p_from_email) = '' THEN
                v_error_msg := 'La configurazione noreply deve specificare un indirizzo email';
            ELSIF p_from_email !~* '(noreply|no-reply|donotreply)' THEN
                v_error_msg := 'L''indirizzo noreply dovrebbe contenere "noreply", "no-reply" o "donotreply"';
            END IF;
    END CASE;
    
    RETURN v_error_msg;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validate_protocol_requirements(p_direction character varying, p_protocol character varying, p_host character varying, p_port integer, p_inbound_host character varying, p_inbound_port integer, p_inbound_protocol character varying)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_error_msg TEXT := '';
BEGIN
    -- Validate outbound requirements
    IF p_direction IN ('outbound', 'both') THEN
        IF p_host IS NULL OR TRIM(p_host) = '' THEN
            v_error_msg := 'Per l''invio email è necessario specificare il server SMTP';
        ELSIF p_port IS NULL THEN
            v_error_msg := 'Per l''invio email è necessario specificare la porta SMTP';
        ELSIF p_port NOT BETWEEN 1 AND 65535 THEN
            v_error_msg := 'La porta SMTP deve essere compresa tra 1 e 65535';
        END IF;
    END IF;
    
    -- Validate inbound requirements
    IF p_direction IN ('inbound', 'both') THEN
        IF p_inbound_host IS NULL OR TRIM(p_inbound_host) = '' THEN
            v_error_msg := 'Per la ricezione email è necessario specificare il server di posta in arrivo';
        ELSIF p_inbound_port IS NULL THEN
            v_error_msg := 'Per la ricezione email è necessario specificare la porta del server';
        ELSIF p_inbound_protocol IS NULL THEN
            v_error_msg := 'Per la ricezione email è necessario specificare il protocollo (IMAP o POP3)';
        ELSIF p_inbound_port NOT BETWEEN 1 AND 65535 THEN
            v_error_msg := 'La porta del server di ricezione deve essere compresa tra 1 e 65535';
        END IF;
    END IF;
    
    RETURN v_error_msg;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validate_security_port_consistency(p_security_method character varying, p_port integer, p_inbound_security_method character varying, p_inbound_port integer, p_inbound_protocol character varying)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_error_msg TEXT := '';
BEGIN
    -- Validate outbound security/port consistency
    IF p_security_method = 'ssl' AND p_port IS NOT NULL THEN
        IF p_port != 465 THEN
            v_error_msg := 'Il protocollo SSL richiede generalmente la porta 465 per SMTP';
        END IF;
    ELSIF p_security_method = 'starttls' AND p_port IS NOT NULL THEN
        IF p_port NOT IN (587, 25) THEN
            v_error_msg := 'Il protocollo STARTTLS richiede generalmente la porta 587 o 25 per SMTP';
        END IF;
    END IF;
    
    -- Validate inbound security/port consistency
    IF p_inbound_security_method = 'ssl' AND p_inbound_port IS NOT NULL THEN
        IF p_inbound_protocol = 'imap' AND p_inbound_port != 993 THEN
            v_error_msg := 'IMAP con SSL richiede generalmente la porta 993';
        ELSIF p_inbound_protocol = 'pop3' AND p_inbound_port != 995 THEN
            v_error_msg := 'POP3 con SSL richiede generalmente la porta 995';
        END IF;
    ELSIF p_inbound_security_method IN ('tls', 'starttls') AND p_inbound_port IS NOT NULL THEN
        IF p_inbound_protocol = 'imap' AND p_inbound_port != 143 THEN
            v_error_msg := 'IMAP con TLS/STARTTLS richiede generalmente la porta 143';
        ELSIF p_inbound_protocol = 'pop3' AND p_inbound_port != 110 THEN
            v_error_msg := 'POP3 con TLS/STARTTLS richiede generalmente la porta 110';
        END IF;
    END IF;
    
    RETURN v_error_msg;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_web_aziende_funzioni_delete(p_id bigint, p_azienda_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_aziende_funzioni WHERE web_aziende_funzioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_web_aziende_funzioni_get(p_id bigint, p_azienda_id integer)
 RETURNS SETOF web_aziende_funzioni
 LANGUAGE sql
 STABLE
AS $function$
    SELECT * FROM web_aziende_funzioni WHERE web_aziende_funzioni_id = p_id AND azienda_id = p_azienda_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_web_indirizzi_get(p_id bigint, p_azienda_id integer)
 RETURNS SETOF web_indirizzi
 LANGUAGE sql
 STABLE
AS $function$
    SELECT * FROM web_indirizzi WHERE web_indirizzi_id = p_id AND azienda_id = p_azienda_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_web_newsletter_blocchi_get(p_id bigint, p_azienda_id integer)
 RETURNS SETOF web_newsletter_blocchi
 LANGUAGE sql
 STABLE
AS $function$
    SELECT * FROM web_newsletter_blocchi
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_web_tour_contenuti_get_by_viaggio(p_viaggio_id integer, p_azienda_id integer)
 RETURNS SETOF web_tour_contenuti
 LANGUAGE sql
 STABLE
AS $function$
    SELECT * FROM web_tour_contenuti WHERE viaggio_id_fk = p_viaggio_id AND azienda_id = p_azienda_id;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_wizard_check_cf_esistenza(p_cf character varying, p_azienda_id integer, p_cliente_id integer DEFAULT NULL::integer)
 RETURNS TABLE(cf_exists boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT EXISTS(
        SELECT 1
        FROM ana_clienti c
        WHERE c.cliente_codicefiscale = p_cf
          AND c.azienda_fk = p_azienda_id
          AND (p_cliente_id IS NULL OR c.cliente_id != p_cliente_id)
    ) AS cf_exists;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_wizard_find_email_by_anagrafica(p_cognome character varying, p_nome character varying, p_cf character varying, p_azienda_id integer)
 RETURNS TABLE(cliente_email character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT c.cliente_email
    FROM ana_clienti c
    WHERE UPPER(c.cliente_cognome) = UPPER(p_cognome)
      AND UPPER(c.cliente_nome) = UPPER(p_nome)
      AND UPPER(c.cliente_codicefiscale) = UPPER(p_cf)
      AND c.azienda_fk = p_azienda_id
    LIMIT 1;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_wizard_find_email_by_cf(p_cf character varying, p_azienda_id integer)
 RETURNS TABLE(cliente_email character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT c.cliente_email
    FROM ana_clienti c
    WHERE UPPER(c.cliente_codicefiscale) = UPPER(p_cf)
      AND c.azienda_fk = p_azienda_id
    LIMIT 1;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_wizard_get_smtp_config(p_azienda_id integer)
 RETURNS TABLE(host character varying, port integer, username character varying, password_value text, use_tls boolean, use_starttls boolean, from_name character varying, from_email text, reply_to text, security_method character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        s.host,
        s.port,
        s.username,
        s.password_enc->>'value' AS password_value,
        s.use_tls,
        s.use_starttls,
        s.from_name,
        s.from_email::TEXT,
        s.reply_to::TEXT,
        s.security_method
    FROM ana_aziende_smtp s
    WHERE s.azienda_fk = p_azienda_id
      AND s.is_active = TRUE
      AND s.config_type = 'outbound'
      AND s.status = 'active'
    ORDER BY s.priority
    LIMIT 1;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_count_travel_future(p_cliente_id integer, p_azienda_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE l_ret integer;
BEGIN
SELECT COUNT(1) INTO l_ret
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
WHERE cv.cliente_id_fk = p_cliente_id
    AND dv.data_viaggio_effettuato_sino = 'N'
    AND dv.data_viaggio_data_inizio > CURRENT_DATE;
RETURN l_ret;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_count_travel_made(p_cliente_id integer, p_azienda_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE l_ret integer;
BEGIN
SELECT COUNT(1) INTO l_ret
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
WHERE cv.cliente_id_fk = p_cliente_id
    AND dv.data_viaggio_effettuato_sino = 'Y';
RETURN l_ret;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hash_password(p_password text)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Usa pgcrypto per hash bcrypt sicuro
    RETURN crypt(p_password, gen_salt('bf'));
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_context(p_user_id uuid)
 RETURNS TABLE(tenant_id text, azienda_id integer, role_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_tenant_id TEXT;
    v_azienda_id INTEGER;
    v_role_code TEXT;
BEGIN
    -- Recupera informazioni utente dalla mappatura
    SELECT 
        urm.tenant_id,
        urm.azienda_id,
        urm.role_code
    INTO 
        v_tenant_id,
        v_azienda_id, 
        v_role_code
    FROM app_user_role_map urm
    WHERE urm.user_id = p_user_id
    LIMIT 1; -- Un utente ha un solo ruolo per semplicità
    
    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Utente non trovato o non ha ruoli assegnati: %', p_user_id;
    END IF;
    
    -- Imposta variabili di sessione
    PERFORM set_config('app.tenant_id', v_tenant_id, false);
    PERFORM set_config('app.azienda_id', COALESCE(v_azienda_id::text, ''), false);
    PERFORM set_config('app.role_code', v_role_code, false);
    PERFORM set_config('app.user_id', p_user_id::text, false);
    
    -- Restituisce informazioni per conferma
    RETURN QUERY SELECT v_tenant_id, v_azienda_id, v_role_code;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_context(p_user_id uuid, p_azienda_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.user_id', p_user_id::text, true);
  PERFORM set_config('app.azienda_id', COALESCE(p_azienda_id::text, ''), true);
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_ana_aliquote_iva_create(p_azienda_fk integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_created_by character varying, p_updated_by character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_iva_id INTEGER;
BEGIN
    -- Validazione parametri obbligatori
    IF p_azienda_fk IS NULL OR p_azienda_fk = 0 THEN
        RAISE EXCEPTION 'AZIENDA_REQUIRED';
    END IF;

    IF p_iva_codice IS NULL OR LENGTH(TRIM(p_iva_codice)) = 0 THEN
        RAISE EXCEPTION 'CODICE_REQUIRED';
    END IF;

    IF p_iva_descrizione IS NULL OR LENGTH(TRIM(p_iva_descrizione)) = 0 THEN
        RAISE EXCEPTION 'DESCRIZIONE_REQUIRED';
    END IF;

    -- Normalizzazione UPPER CASE (il constraint la verifica, ma la forziamo)
    p_iva_codice := UPPER(TRIM(p_iva_codice));
    p_iva_descrizione := UPPER(TRIM(p_iva_descrizione));
    IF p_iva_natura IS NOT NULL THEN
        p_iva_natura := UPPER(TRIM(p_iva_natura));
    END IF;

    -- Insert
    INSERT INTO ana_aliquote_iva (
        azienda_fk,
        iva_codice,
        iva_descrizione,
        iva_percentuale,
        iva_natura,
        is_default,
        is_active,
        ordinamento,
        created_at,
        created_by,
        updated_at,
        updated_by
    ) VALUES (
        p_azienda_fk,
        p_iva_codice,
        p_iva_descrizione,
        COALESCE(p_iva_percentuale, 0),
        p_iva_natura,
        COALESCE(p_is_default, FALSE),
        COALESCE(p_is_active, TRUE),
        COALESCE(p_ordinamento, 100),
        NOW(),
        p_created_by,
        NOW(),
        p_updated_by
    )
    RETURNING iva_id INTO v_iva_id;

    RETURN v_iva_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_AZIENDA';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA';
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_ana_aliquote_iva_delete(p_iva_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (SELECT 1 FROM ana_aliquote_iva WHERE iva_id = p_iva_id) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Delete
    DELETE FROM ana_aliquote_iva
    WHERE iva_id = p_iva_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'RECORD_IN_USE';
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_ana_aliquote_iva_set_default(p_iva_id integer, p_azienda_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (
        SELECT 1 FROM ana_aliquote_iva
        WHERE iva_id = p_iva_id
          AND azienda_fk = p_azienda_id
    ) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Imposta come default
    -- Il trigger fn_check_single_default_iva rimuoverà automaticamente
    -- il flag dalle altre aliquote della stessa azienda
    UPDATE ana_aliquote_iva
    SET
        is_default = TRUE,
        updated_at = NOW()
    WHERE iva_id = p_iva_id
      AND azienda_fk = p_azienda_id;

END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_ana_aliquote_iva_update(p_iva_id integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_updated_by character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (SELECT 1 FROM ana_aliquote_iva WHERE iva_id = p_iva_id) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Validazione parametri obbligatori
    IF p_iva_codice IS NULL OR LENGTH(TRIM(p_iva_codice)) = 0 THEN
        RAISE EXCEPTION 'CODICE_REQUIRED';
    END IF;

    IF p_iva_descrizione IS NULL OR LENGTH(TRIM(p_iva_descrizione)) = 0 THEN
        RAISE EXCEPTION 'DESCRIZIONE_REQUIRED';
    END IF;

    -- Normalizzazione UPPER CASE
    p_iva_codice := UPPER(TRIM(p_iva_codice));
    p_iva_descrizione := UPPER(TRIM(p_iva_descrizione));
    IF p_iva_natura IS NOT NULL THEN
        p_iva_natura := UPPER(TRIM(p_iva_natura));
    END IF;

    -- Update
    UPDATE ana_aliquote_iva
    SET
        iva_codice = p_iva_codice,
        iva_descrizione = p_iva_descrizione,
        iva_percentuale = COALESCE(p_iva_percentuale, 0),
        iva_natura = p_iva_natura,
        is_default = COALESCE(p_is_default, FALSE),
        is_active = COALESCE(p_is_active, TRUE),
        ordinamento = COALESCE(p_ordinamento, 100),
        updated_at = NOW(),
        updated_by = p_updated_by
    WHERE iva_id = p_iva_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA';
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_ana_aziende_smtp_test_connection(p_smtp_id uuid)
 RETURNS TABLE(success boolean, message text, response_time_ms integer, connection_status character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_config ana_aziende_smtp%ROWTYPE;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_response_time INTEGER;
    v_status VARCHAR(20);
    v_error_msg TEXT;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Get configuration
    SELECT * INTO v_config
    FROM ana_aziende_smtp
    WHERE smtp_id = p_smtp_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Configurazione email non trovata', 0, 'error'::VARCHAR(20);
        RETURN;
    END IF;
    
    IF NOT v_config.is_active THEN
        RETURN QUERY SELECT false, 'La configurazione email non è attiva', 0, 'inactive'::VARCHAR(20);
        RETURN;
    END IF;
    
    -- Basic validation
    IF v_config.host IS NULL OR v_config.port IS NULL THEN
        v_status := 'error';
        v_error_msg := 'Configurazione incompleta: mancano host o porta';
    ELSE
        -- Simulate connection test (in production, implement actual SMTP test)
        PERFORM pg_sleep(0.1); -- Simulate network delay
        v_status := 'success';
        v_error_msg := NULL;
    END IF;
    
    v_end_time := clock_timestamp();
    v_response_time := EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time))::INTEGER;
    
    -- Update test results
    UPDATE ana_aziende_smtp
    SET 
        last_test_date = NOW(),
        connection_status = v_status,
        test_error_message = v_error_msg,
        last_success_date = CASE WHEN v_status = 'success' THEN NOW() ELSE last_success_date END,
        updated_at = NOW()
    WHERE smtp_id = p_smtp_id;
    
    IF v_status = 'success' THEN
        RETURN QUERY SELECT true, 'Test di connessione completato con successo', v_response_time, v_status;
    ELSE
        RETURN QUERY SELECT false, COALESCE(v_error_msg, 'Test di connessione fallito'), v_response_time, v_status;
    END IF;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_resolve_room_violation_park(p_room_id integer, p_survivor_ids integer[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    i integer;
BEGIN
    -- Semplicemente rimuove i survivor dalla stanza corrente
    FOREACH i IN ARRAY p_survivor_ids
    LOOP
        PERFORM sp_remove_client_from_room(p_room_id, i);
    END LOOP;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_app_users_login_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF OLD.last_login_at IS DISTINCT FROM NEW.last_login_at THEN
        NEW.login_count = COALESCE(OLD.login_count, 0) + 1;
    END IF;
    RETURN NEW;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_app_users_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_user_roles_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$
;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Aggiorna sempre il timestamp di modifica
    NEW.updated_at = CURRENT_TIMESTAMP;
    
    -- Se il record diventa non corrente, imposta valid_to
    IF NEW.is_current = FALSE AND OLD.is_current = TRUE THEN
        NEW.valid_to = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$function$
;
