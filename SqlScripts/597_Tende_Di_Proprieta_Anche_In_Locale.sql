-- =============================================================================
-- 597 — Le tende di proprietà mancavano al database locale
-- =============================================================================
--
-- Trovato il 2026-09-06 verificando su PROD, e non in locale, la questione della
-- composizione delle tende.
--
-- ⚠️ I due cataloghi non coincidevano: PROD ha **15** tipi di alloggio, il database
-- di sviluppo ne aveva **13**. I due mancanti sono proprio quelli che servono al
-- caso in discussione:
--
--     34  TENDA 2 POSTI DI PROPRIETA'   2 posti   supplemento N
--     36  TENDA 4 POSTI DI PROPRIETA'   4 posti   supplemento N
--
-- La sera prima avevo scritto nell'analisi che «a catalogo ci sono solo tende
-- NOLEGGIATE, quindi serve un tipo tenda propria»: vero in locale, **falso su
-- PROD**, dove esiste già ed è pure impostato correttamente senza supplemento.
--
-- ⚠️ Il punto non è la riga mancante, è che una **tabella di riferimento divergente
-- fa mentire le prove**: si sarebbe collaudata la composizione delle tende su un
-- database che le tende di proprietà non le ha, concludendo che funziona.
--
-- Gli identificativi sono gli stessi di PROD di proposito: un tipo di alloggio va
-- riconosciuto per numero, e due cataloghi che numerano diversamente la stessa cosa
-- sono peggio di uno incompleto.
-- =============================================================================

INSERT INTO ana_tipo_alloggio
    (tipo_alloggio_id, tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento)
VALUES
    (34, 'TENDA 2 POSTI DI PROPRIETA''', 2, 'N'),
    (36, 'TENDA 4 POSTI DI PROPRIETA''', 4, 'N')
ON CONFLICT (tipo_alloggio_id) DO UPDATE
    SET tipo_alloggio_descrizione     = EXCLUDED.tipo_alloggio_descrizione,
        tipo_alloggio_numero_occupanti = EXCLUDED.tipo_alloggio_numero_occupanti,
        tipo_alloggio_supplemento      = EXCLUDED.tipo_alloggio_supplemento;

-- ⚠️ Su PROD questo script non aggiunge niente: le due righe ci sono già ed è da lì
-- che sono state copiate. Serve ad allineare l'ambiente di sviluppo, ed è
-- rigiocabile senza effetti.
