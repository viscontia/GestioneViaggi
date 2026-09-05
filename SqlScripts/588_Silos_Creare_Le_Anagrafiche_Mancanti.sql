-- =============================================================================
-- 588 — Chi ha viaggiato con un'azienda diventa un cliente DI quell'azienda
-- =============================================================================
--
-- Deciso il 2026-09-05, dopo la misura dello script 587: il rimappaggio «prendi il
-- suo codice nell'azienda del viaggio» funziona solo dove quel codice esiste, e su
-- PROD esisteva per **1 persona su 25**. Per le altre 24 l'anagrafica nell'azienda
-- 2 non c'era affatto — non un riferimento sbagliato, una scheda mai creata.
--
-- La scelta: crearla. E' la lettura fedele al modello a silos — chi ha viaggiato
-- con SFT e' un cliente di SFT, e deve stare nella sua anagrafica. Sono persone
-- reali che con SFT ci sono andate davvero: la famiglia MAZZOLENI a PASQUA IN
-- BARBAGIA, i sette di CAPODANNO JOKERS, i quattro di CAPODANNO IN OGLIASTRA.
--
-- ⚠️ NON si copia il consenso al marketing. Chi ha detto sì (o no) l'ha detto a
-- un'altra azienda, e il consenso vale verso chi lo ha raccolto: portarselo dietro
-- significherebbe scrivere a qualcuno che non ha mai autorizzato QUESTA azienda.
-- La scheda nuova nasce quindi come «mai chiesto», ed e' esattamente lo stato in
-- cui le regole dello script 581 la fanno chiedere alla prima occasione utile.
--
-- ⚠️ Si esegue DOPO lo script 587, che definisce le funzioni usate qui.
-- =============================================================================

DO $$
DECLARE
    -- Cio' che NON si copia dalla scheda di origine.
    --   la chiave          → la assegna il database
    --   l'azienda          → e' il punto di tutta l'operazione
    --   le tracce di modifica → questa scheda nasce ora
    --   il consenso        → si veda sopra: non e' trasferibile
    v_esclusi TEXT[] := ARRAY[
        'cliente_id', 'azienda_fk',
        'created_by', 'created', 'updated_by', 'updated',
        'consenso_marketing', 'consenso_marketing_data', 'consenso_marketing_fonte',
        'consenso_marketing_chiesto_data', 'consenso_marketing_chiesto_fonte'
    ];
    v_colonne TEXT;
    v_creati  INTEGER := 0;
    r         RECORD;
BEGIN
    -- L'elenco delle colonne si legge dal catalogo invece di scriverlo a mano: la
    -- tabella ne ha piu' di quaranta e ne nascono di nuove. Una colonna aggiunta
    -- domani entra da sola nella copia, invece di essere dimenticata.
    SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
      INTO v_colonne
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ana_clienti'
      AND NOT (column_name = ANY(v_esclusi));

    -- Una persona sola alla volta, anche se ha piu' movimenti fuori silo.
    FOR r IN
        SELECT DISTINCT s.cliente_id, s.azienda_viaggio, s.nominativo
        FROM fn_silos_movimenti_fuori_azienda() s
        WHERE s.rimediabile = 'GEMELLO_ASSENTE'
        ORDER BY s.nominativo
    LOOP
        -- Rieseguibile: se nel frattempo la scheda esiste, non se ne crea una seconda.
        CONTINUE WHEN fn_cliente_gemello_in_azienda(r.cliente_id, r.azienda_viaggio) IS NOT NULL;

        EXECUTE format(
            'INSERT INTO ana_clienti (%s, azienda_fk, created_by, created)
             SELECT %s, $1, ''migrazione_silos'', now() FROM ana_clienti WHERE cliente_id = $2',
            v_colonne, v_colonne)
        USING r.azienda_viaggio, r.cliente_id;

        v_creati := v_creati + 1;
        RAISE NOTICE 'creata scheda per % nell''azienda %', r.nominativo, r.azienda_viaggio;
    END LOOP;

    RAISE NOTICE '--- anagrafiche create: % ---', v_creati;
END;
$$;

-- Ora che le schede ci sono, i movimenti possono puntarci. Stessa funzione dello
-- script 587: la regola di rimappaggio resta scritta in un posto solo.
SELECT fn_silos_rimappa_movimenti() AS righe_rimappate;

-- Referto finale: deve restare vuoto.
SELECT s.rimediabile, s.tabella, count(*) AS righe
FROM fn_silos_movimenti_fuori_azienda() s
GROUP BY 1, 2 ORDER BY 1, 2;
