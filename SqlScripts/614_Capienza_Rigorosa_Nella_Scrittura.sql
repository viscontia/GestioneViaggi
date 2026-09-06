-- =============================================================================
-- 614 — La capienza si controlla dove si scrive, non solo dove si guarda
-- =============================================================================
--
-- Il 2026-09-06 Adriano ha deciso: «le camere vanno assegnate in modo rigoroso sul
-- rapporto persone/capienza e non ci devono essere scappatoie. Se poi con l'albergo
-- si verificheranno situazioni particolari rimarranno offline».
--
-- Nello stesso pomeriggio ne e' comparsa una: iscrivendo un passeggero dalla scheda
-- Partecipanti si poteva creare una CAMERA MATRIMONIALE con UNA persona sola. Non
-- era un difetto nuovo — quella strada non e' MAI passata da un controllo di
-- capienza. Il controllo esiste (`fn_alloggi_assegnazione_valida`), ma lo chiama
-- solo la gestione alloggi: ⚠️ una regola applicata in un punto solo del percorso,
-- che e' lo stesso schema trovato oggi altre tre volte.
--
-- Ora sta nella funzione che SCRIVE, dove nessuna interfaccia la puo' saltare.
--
-- ⚠️ Il genere NESSUNA e' escluso, e non e' una scappatoia: «nessuna sistemazione»
-- ha capienza 0 e un occupante — e' cosi' che si registra chi dorme nel proprio
-- mezzo. Una regola secca `occupanti = capienza` le romperebbe tutte (misurate: 2
-- su PROD, azienda 2).
--
-- ⚠️ Le 7 assegnazioni storiche sotto capienza (le «doppie uso singola» di cui
-- parlava Antonio) NON vengono toccate: questa funzione e' nata ieri e in PROD non
-- l'ha ancora usata nessuno. Restano com'erano finche' qualcuno non le modifica.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_alloggi_salva_camera(
    p_alloggio_pk      INTEGER,
    p_viaggio_id       INTEGER,
    p_data_viaggio_id  INTEGER,
    p_tipo_alloggio_id INTEGER,
    p_clienti          INTEGER[]
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_pk        INTEGER;
    v_clienti   INTEGER[] := COALESCE(p_clienti, ARRAY[]::INTEGER[]);
    v_quanti    INTEGER   := cardinality(COALESCE(p_clienti, ARRAY[]::INTEGER[]));
    v_capienza  INTEGER;
    v_tipo      VARCHAR;
    v_genere    VARCHAR;
    r           RECORD;
    v_restano   INTEGER[];
BEGIN
    IF array_length(v_clienti, 1) IS DISTINCT FROM cardinality(ARRAY(SELECT DISTINCT unnest(v_clienti))) THEN
        RAISE EXCEPTION 'La stessa persona è indicata due volte nella stessa sistemazione.'
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_descrizione, g.genere_codice
      INTO v_capienza, v_tipo, v_genere
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE t.tipo_alloggio_id = p_tipo_alloggio_id;

    IF v_capienza IS NULL THEN
        RAISE EXCEPTION 'La sistemazione indicata non esiste.' USING ERRCODE = 'check_violation';
    END IF;

    -- ⚠️ «Nessuna sistemazione» ha capienza 0 e un occupante: e' il modo in cui si
    -- registra chi dorme nel proprio mezzo, non un'eccezione alla regola.
    IF v_genere <> 'NESSUNA' AND v_quanti <> v_capienza THEN
        RAISE EXCEPTION
            '«%» ospita % persone, ne %. La capienza deve corrispondere: se serve una sistemazione diversa, cambia il tipo.',
            v_tipo, v_capienza,
            CASE WHEN v_quanti = 0 THEN 'è stata indicata nessuna'
                 WHEN v_quanti = 1 THEN 'è stata indicata 1'
                 ELSE 'sono state indicate ' || v_quanti END
            USING ERRCODE = 'check_violation';
    END IF;

    -- ---------------------------------------------------------------------
    -- 1. La sistemazione di destinazione
    -- ---------------------------------------------------------------------
    IF COALESCE(p_alloggio_pk, 0) = 0 THEN
        -- ⚠️ La chiave la assegna la sequenza a mano: questa tabella non ha default
        -- sulla colonna e non ha trigger, come fa sp_mov_clienti_alloggi_create.
        INSERT INTO mov_clienti_alloggi (
            mov_clienti_alloggio_pk,
            viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk,
            cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
            cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)
        VALUES (nextval('mov_clienti_alloggi_seq'),
                p_viaggio_id, p_data_viaggio_id, p_tipo_alloggio_id,
                v_clienti[1], v_clienti[2], v_clienti[3],
                v_clienti[4], v_clienti[5], v_clienti[6])
        RETURNING mov_clienti_alloggio_pk INTO v_pk;
    ELSE
        UPDATE mov_clienti_alloggi
           SET tipo_alloggio_id_fk = p_tipo_alloggio_id,
               cliente_id1_fk = v_clienti[1], cliente_id2_fk = v_clienti[2],
               cliente_id3_fk = v_clienti[3], cliente_id4_fk = v_clienti[4],
               cliente_id5_fk = v_clienti[5], cliente_id6_fk = v_clienti[6]
         WHERE mov_clienti_alloggio_pk = p_alloggio_pk
        RETURNING mov_clienti_alloggio_pk INTO v_pk;

        IF v_pk IS NULL THEN
            RAISE EXCEPTION 'La sistemazione % non esiste più: forse qualcun altro l''ha eliminata mentre la stavi modificando.', p_alloggio_pk
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- ---------------------------------------------------------------------
    -- 2. Chi arriva da un'altra sistemazione, ne esce
    -- ---------------------------------------------------------------------
    IF array_length(v_clienti, 1) > 0 THEN
        FOR r IN
            SELECT a.mov_clienti_alloggio_pk AS pk,
                   ARRAY(SELECT c FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                                    a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) c
                          WHERE c IS NOT NULL AND NOT (c = ANY (v_clienti))) AS restano
            FROM mov_clienti_alloggi a
            WHERE a.data_viaggio_id_fk = p_data_viaggio_id
              AND a.mov_clienti_alloggio_pk <> v_pk
              AND ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk] && v_clienti
        LOOP
            v_restano := r.restano;

            IF cardinality(v_restano) = 0 THEN
                DELETE FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = r.pk;
            ELSE
                -- ⚠️ Chi resta e' MENO di prima, quindi quella sistemazione ora e' sotto
                -- capienza. Non si puo' rifiutare — sarebbe impossibile spostare qualcuno
                -- da una doppia — ma non si puo' nemmeno lasciarla incoerente in silenzio:
                -- il tipo si adegua a chi rimane, scegliendo con la stessa regola del
                -- suggerimento (capienza esatta, preferendo senza supplemento).
                UPDATE mov_clienti_alloggi
                   SET cliente_id1_fk = v_restano[1], cliente_id2_fk = v_restano[2],
                       cliente_id3_fk = v_restano[3], cliente_id4_fk = v_restano[4],
                       cliente_id5_fk = v_restano[5], cliente_id6_fk = v_restano[6],
                       tipo_alloggio_id_fk = COALESCE(
                           (SELECT x.tipo_id FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) x
                             WHERE x.posti = cardinality(v_restano) AND NOT x.mai_proposta
                             ORDER BY x.supplemento, x.tipo_id LIMIT 1),
                           tipo_alloggio_id_fk)
                 WHERE mov_clienti_alloggio_pk = r.pk;
            END IF;
        END LOOP;
    END IF;

    RETURN v_pk;
END;
$$;

COMMENT ON FUNCTION fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[]) IS
'Salva una sistemazione e, nella stessa transazione, toglie i suoi occupanti dalle altre
sistemazioni della STESSA partenza: quelle che restano vuote si eliminano, quelle che
restano con meno persone si adeguano al tipo della capienza giusta.
⛔️ La capienza deve CORRISPONDERE al numero di occupanti — nessuna scappatoia, decisione del
2026-09-06 — tranne per il genere NESSUNA, dove capienza 0 con un occupante e'' il modo in cui
si registra chi dorme nel proprio mezzo.';
