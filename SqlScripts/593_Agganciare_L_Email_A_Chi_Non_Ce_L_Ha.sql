-- =============================================================================
-- 593 — Chi è già cliente ma non ha un'email non resta fuori: gliela si aggancia
-- =============================================================================
--
-- Trovato dall'utente il 2026-09-05 col test F7. Il sito identifica le persone
-- DALL'EMAIL — è la prima cosa che chiede — mentre il gestionale non la pretende,
-- e fa bene: la passeggera che non lascia il proprio indirizzo sta esercitando una
-- scelta legittima. Le due regole non coincidono, e chi è in anagrafica senza email
-- dal sito non riesce a iscriversi.
--
-- Su PROD (azienda 2) sono 8 clienti su 206. Sette vengono riconosciuti da
-- `fn_ana_clienti_verifica_duplicato` e rifiutati — quindi la scheda doppia NON
-- nasce, ma la persona resta fuori. L'ottava, GENDUSO FRANCESCA, non ha la data di
-- nascita: lei non viene riconosciuta affatto, e il doppione si creerebbe davvero.
-- ⚠️ Sono tutte donne: passeggere iscritte da altri, senza un indirizzo proprio.
--
-- Decisione dell'utente, 2026-09-05: **si aggancia l'email alla scheda esistente**.
-- È la stessa regola già scelta per la pagina pubblica della newsletter — «chi si
-- iscrive da quel link ed è già cliente: aggiornare la sua scheda».
--
-- ⚠️ Si scrive SOLO su una scheda che l'email non ce l'ha. Se una c'è già, questa
-- funzione non la tocca: sovrascrivere l'indirizzo di qualcuno perché un'omonima
-- si è iscritta sarebbe molto peggio del problema che si sta risolvendo.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_clienti_aggancia_email(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER,
    p_email      VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE v_righe INTEGER;
BEGIN
    IF btrim(COALESCE(p_email, '')) = '' THEN
        RETURN FALSE;
    END IF;

    UPDATE ana_clienti
       SET cliente_email = btrim(p_email)
     WHERE cliente_id = p_cliente_id
       -- L'azienda: la scheda dev'essere di chi sta chiedendo. Senza questo
       -- vincolo si potrebbe scrivere l'email sul cliente di un'altra azienda
       -- passando un identificativo qualsiasi.
       AND azienda_fk = p_azienda_id
       -- Solo se ne è priva. E' la condizione che rende l'operazione sicura:
       -- non si sovrascrive mai un recapito esistente.
       AND nullif(btrim(cliente_email), '') IS NULL;

    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe > 0;
END;
$$;

COMMENT ON FUNCTION fn_ana_clienti_aggancia_email(INTEGER, INTEGER, VARCHAR) IS
'Completa con un''email la scheda di un cliente che ne e'' privo, e solo in quel caso.
Serve a chi e'' gia'' in anagrafica senza indirizzo e si presenta sul sito: senza questo
verrebbe riconosciuto e respinto, perche'' il sito identifica le persone dall''email.
⚠️ Non sovrascrive mai un recapito che c''e'' gia''.';
