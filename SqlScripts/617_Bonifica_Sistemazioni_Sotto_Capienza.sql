-- =============================================================================
-- 617 — Le sistemazioni storiche con la capienza sbagliata — RAPPORTO, non lavoro
-- =============================================================================
--
-- ⛔️ **NON C'E' NIENTE DA FARE, e non e' un rinvio: e' un accertamento.**
--
-- Rilievo di Adriano il 2026-09-06: «guarda che per viaggi gia' conclusi non cambia
-- nulla». Misurato subito dopo, e ha ragione in pieno:
--
--   • in locale, 11 righe incoerenti — TUTTE su partenze concluse (fn_partenza_conclusa);
--   • su PROD azienda 2, 7 righe — TUTTE su partenze gia' finite, la piu' recente del
--     18/05/2026 (misurato in sola lettura il 2026-09-06);
--   • su partenze FUTURE: ZERO, in entrambi gli ambienti.
--
-- Il controllo dello script 616 scatta solo su inserimento e modifica. Nessuno modifica
-- le camere di un viaggio gia' fatto, quindi quelle righe non incontreranno mai la
-- guardia: restano dove sono, come testimonianza di com'e' andata.
--
-- ⚠️ Questo file resta come RAPPORTO da rilanciare quando serve: se un domani il conto
-- non fosse piu' zero sulle partenze future, vorrebbe dire che qualcosa scrive
-- aggirando le funzioni, e allora sarebbe un difetto da cercare.
--
-- ⛔️ La correzione qui sotto e' COMMENTATA e va lasciata tale finche' non serve. Cambia
-- dati veri — il TIPO di sistemazioni
-- gia' registrate, che ha un prezzo e un supplemento — e la decisione e' di Adriano,
-- riga per riga se serve.
--
-- Dallo script 616 la capienza deve corrispondere agli occupanti. Le righe scritte
-- prima restano dove sono, ⚠️ ma non saranno piu' modificabili finche' non si
-- sistemano: toccandole, il trigger le rifiuta.
--
-- Misurate il 2026-09-06: 11 in locale (9 azienda 2, 2 azienda 6), 7 su PROD
-- azienda 2. Sono quasi tutte «doppie con un occupante solo» — parola di Antonio:
-- «quell'albergo non offriva camere singole», cioe' una doppia pagata a uso singola
-- registrata col tipo sbagliato. Per quelle esiste gia' il tipo giusto:
-- CAMERA DOPPIA USO SINGOLA, da 1 posto.
--
-- ⚠️ Non e' una semplice correzione tecnica: cambiare il tipo cambia la descrizione
-- che finisce nei documenti e il supplemento. Va guardata, non eseguita a occhi
-- chiusi.
--
-- ⛔️ **E la proposta automatica qui sotto sbaglia proprio su questo caso.** La colonna
-- `tipo_proposto` applica la stessa regola del suggerimento — capienza giusta,
-- preferendo senza supplemento — e per una persona sola tira fuori CAMERA SINGOLA.
-- Ma se l'albergo le camere singole non le aveva, la verita' e' CAMERA DOPPIA USO
-- SINGOLA: stessa capienza, significato e prezzo diversi. Il programma non puo'
-- saperlo, lo sa chi ha prenotato. Usa `tipo_proposto` come punto di partenza, non
-- come risposta.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PRIMA: guardare che cosa c'e'. Questa parte non modifica niente.
-- ---------------------------------------------------------------------------
SELECT a.mov_clienti_alloggio_pk        AS chiave,
       v.azienda_id                     AS azienda,
       v.viaggio_descrizione_breve      AS viaggio,
       dv.data_viaggio_data_inizio      AS partenza,
       fn_partenza_conclusa(dv.data_viaggio_id) AS gia_conclusa,
       t.tipo_alloggio_descrizione      AS tipo_ora,
       t.tipo_alloggio_numero_occupanti AS capienza,
       (SELECT count(*) FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                          a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) x
         WHERE x IS NOT NULL)           AS occupanti,
       (SELECT string_agg(c.cliente_cognome || ' ' || c.cliente_nome, ', ')
          FROM ana_clienti c
         WHERE c.cliente_id = ANY(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk])) AS chi_c_e,
       -- Il tipo della capienza giusta, preferendo quello senza supplemento.
       (SELECT t2.tipo_alloggio_descrizione
          FROM ana_tipo_alloggio t2
         WHERE t2.genere_fk = t.genere_fk
           AND t2.tipo_alloggio_numero_occupanti =
               (SELECT count(*) FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                                  a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) y
                 WHERE y IS NOT NULL)
           AND NOT t2.tipo_alloggio_mai_proposta
         ORDER BY t2.tipo_alloggio_supplemento, t2.tipo_alloggio_id
         LIMIT 1)                       AS tipo_proposto
FROM mov_clienti_alloggi a
JOIN ana_tipo_alloggio t   ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
JOIN ana_viaggi v          ON v.viaggio_id = a.viaggio_id_fk
JOIN ana_date_viaggi dv    ON dv.data_viaggio_id = a.data_viaggio_id_fk
WHERE g.genere_codice <> 'NESSUNA'
  AND t.tipo_alloggio_numero_occupanti <> (
      SELECT count(*) FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) z
       WHERE z IS NOT NULL)
ORDER BY v.azienda_id, dv.data_viaggio_data_inizio DESC;


-- ---------------------------------------------------------------------------
-- POI, e solo dopo aver guardato: la correzione.
-- ---------------------------------------------------------------------------
-- ⛔️ Volutamente COMMENTATA. Toglila tu quando hai deciso, e considera di farla
-- azienda per azienda: la 6 non ha senso in produzione (deciso il 2026-09-05),
-- quindi le sue due righe potrebbero non valere la pena.
--
-- UPDATE mov_clienti_alloggi a
--    SET tipo_alloggio_id_fk = (
--        SELECT t2.tipo_alloggio_id FROM ana_tipo_alloggio t2
--         WHERE t2.genere_fk = t.genere_fk
--           AND t2.tipo_alloggio_numero_occupanti = (
--               SELECT count(*) FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
--                                                 a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) y
--                WHERE y IS NOT NULL)
--           AND NOT t2.tipo_alloggio_mai_proposta
--         ORDER BY t2.tipo_alloggio_supplemento, t2.tipo_alloggio_id
--         LIMIT 1)
--   FROM ana_tipo_alloggio t, ana_alloggio_generi g, ana_viaggi v
--  WHERE t.tipo_alloggio_id = a.tipo_alloggio_id_fk
--    AND g.genere_id = t.genere_fk
--    AND v.viaggio_id = a.viaggio_id_fk
--    AND v.azienda_id = 2                      -- ⚠️ una azienda per volta
--    AND g.genere_codice <> 'NESSUNA'
--    AND t.tipo_alloggio_numero_occupanti <> (
--        SELECT count(*) FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
--                                          a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) z
--         WHERE z IS NOT NULL);
--
-- ⚠️ Dove non esiste un tipo della capienza giusta la sottoquery torna NULL e la
-- riga fallirebbe sul NOT NULL: guarda la colonna `tipo_proposto` del rapporto qui
-- sopra prima di lanciarla.
