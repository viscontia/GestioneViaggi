-- Guardie sulla cancellazione di una partenza.
--
-- Prima di questo script sp_ana_date_viaggi_delete controllava SOLO mov_clienti_viaggi e
-- mov_clienti_alloggi. Due conseguenze, entrambe verificate in locale:
--
-- 1) Una partenza con contenuti web era bloccata dalla FK (NO ACTION) invece che dal controllo di
--    business: l'utente riceveva un'eccezione PostgreSQL avvolta in un messaggio generico ("utilizzato
--    in altre parti del sistema"), loggata come errore e mostrata in rosso, mentre il caso partecipanti
--    - identico come natura - risulta un avviso giallo.
--
-- 2) Una partenza GIA' EFFETTUATA e nel passato era cancellabile senza alcuna domanda: nessun controllo
--    esisteva né sulle date né sul flag. Verificato: partenza di 400 giorni fa con flag 'Y' e nessun
--    partecipante -> deleted = true. L'unica protezione era accidentale (di solito quelle partenze hanno
--    partecipanti, e quelli bloccano), quindi non valeva quando i partecipanti non erano mai stati
--    registrati o erano stati rimossi: spariva storico aziendale in modo irreversibile.
--
-- Scelta: blocco totale sullo storico. Si elimina solo una partenza che deve ancora iniziare e non è
-- segnata come effettuata. È lo stesso confine usato altrove (pubblicabilità in scrittura e filtro del
-- sito in lettura): una partenza iniziata oggi è già storico.
--
-- Nota per chi legge dopo: chi sbaglia a inserire una data nel passato può correggerla e poi eliminarla.
-- È deliberatamente un passaggio in due mosse, non una scorciatoia.
--
-- Ordine dei controlli: prima lo storico (è la ragione più forte e la più utile da leggere), poi i
-- contenuti web, infine partecipanti e alloggi (invariati).

CREATE OR REPLACE FUNCTION public.sp_ana_date_viaggi_delete(p_data_viaggio_id integer)
 RETURNS TABLE(deleted boolean, error_message text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inizio        DATE;
    v_effettuata    BOOLEAN;
    v_quando        TEXT;
    v_stato_web     VARCHAR;
    v_clienti_count BIGINT;
    v_alloggi_count BIGINT;
BEGIN
    SELECT dv.data_viaggio_data_inizio,
           COALESCE(dv.data_viaggio_effettuato_sino, 'N') = 'Y'
      INTO v_inizio, v_effettuata
      FROM ana_date_viaggi dv
     WHERE dv.data_viaggio_id = p_data_viaggio_id;

    IF NOT FOUND THEN
        deleted := FALSE;
        error_message := 'Data viaggio non trovata';
        RETURN NEXT;
        RETURN;
    END IF;

    v_quando := COALESCE(to_char(v_inizio, 'DD/MM/YYYY'), 'senza data di inizio');

    -- 1) Storico aziendale: non si cancella.
    IF v_effettuata THEN
        deleted := FALSE;
        error_message := format(
            'Impossibile eliminare la partenza del %s: è segnata come effettuata e fa parte dello storico aziendale.',
            v_quando);
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_inizio IS NOT NULL AND v_inizio <= CURRENT_DATE THEN
        deleted := FALSE;
        error_message := format(
            'Impossibile eliminare la partenza del %s: è già iniziata e fa parte dello storico. Si può eliminare solo una partenza che deve ancora iniziare.',
            v_quando);
        RETURN NEXT;
        RETURN;
    END IF;

    -- 2) Contenuti web: la FK li protegge comunque, ma qui il rifiuto diventa un messaggio di business
    --    che dice QUALE ostacolo c'è e in che stato è, invece di un errore di vincolo.
    SELECT c.stato_pubblicazione
      INTO v_stato_web
      FROM web_tour_contenuti c
     WHERE c.data_viaggio_id_fk = p_data_viaggio_id
     LIMIT 1;

    IF v_stato_web IS NOT NULL THEN
        deleted := FALSE;
        error_message := CASE
            WHEN v_stato_web = 'pubblicato' THEN format(
                'Impossibile eliminare la partenza del %s: ha una scheda di contenuti web PUBBLICATA. Riportala a bozza ed elimina la scheda, poi riprova.',
                v_quando)
            ELSE format(
                'Impossibile eliminare la partenza del %s: ha una scheda di contenuti web (stato: %s). Elimina prima la scheda, poi riprova.',
                v_quando, v_stato_web)
        END;
        RETURN NEXT;
        RETURN;
    END IF;

    -- 3) Prenotazioni e alloggi: controllo preesistente, invariato.
    SELECT COUNT(1) INTO v_clienti_count
    FROM mov_clienti_viaggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id;

    SELECT COUNT(1) INTO v_alloggi_count
    FROM mov_clienti_alloggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id;

    IF v_clienti_count > 0 OR v_alloggi_count > 0 THEN
        deleted := FALSE;
        error_message := format(
            'Impossibile eliminare la data: esistono dati collegati (%s%s%s).',
            CASE WHEN v_clienti_count > 0 THEN v_clienti_count || ' clienti' ELSE '' END,
            CASE WHEN v_clienti_count > 0 AND v_alloggi_count > 0 THEN ' e ' ELSE '' END,
            CASE WHEN v_alloggi_count > 0 THEN v_alloggi_count || ' alloggi' ELSE '' END
        );
        RETURN NEXT;
        RETURN;
    END IF;

    DELETE FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id;

    IF FOUND THEN
        deleted := TRUE;
        error_message := NULL;
    ELSE
        deleted := FALSE;
        error_message := 'Data viaggio non trovata';
    END IF;

    RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION public.sp_ana_date_viaggi_delete(integer) IS
'Elimina una partenza previe guardie: rifiuta le partenze effettuate o già iniziate (storico aziendale), quelle con una scheda di contenuti web e quelle con prenotazioni o alloggi. Ritorna (deleted, error_message) invece di sollevare eccezioni, così la UI mostra un avviso e non un errore.';
