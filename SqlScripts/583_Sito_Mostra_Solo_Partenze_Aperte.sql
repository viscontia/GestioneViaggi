-- =============================================================================
-- 583 — Il sito mostra le partenze che il database accetta, e nessun'altra
-- =============================================================================
--
-- Trovato il 2026-09-04 provando i test D9 e D10, che sul sito non erano
-- eseguibili «perche' l'elenco presenta solo viaggi con data futura». Vero, ma
-- il criterio con cui li sceglieva era sbagliato in due modi.
--
-- 1. `data_viaggio_effettuato_sino != 'S'` confronta con un valore CHE NON
--    ESISTE: il vincolo sulla colonna ammette solo 'Y', 'N' e 'P'. La condizione
--    e' quindi sempre vera, e non esclude niente. Una partenza futura marcata
--    come effettuata — un viaggio annullato, per dire — sarebbe stata mostrata
--    fra quelle prenotabili, e poi rifiutata dal database (script 578) dopo che
--    la persona aveva compilato tutto. Oggi non ce n'e' nessuna in quello stato,
--    quindi il difetto e' latente: si vedrebbe il giorno in cui capita.
--
-- 2. Il criterio era comunque una SECONDA definizione di «partenza aperta»,
--    diversa da fn_partenza_conclusa che governa l'iscrizione. Due definizioni
--    della stessa cosa divergono sempre — e queste avevano gia' divergerto.
--
-- Ora la funzione chiama fn_partenza_conclusa: cio' che il sito mostra e cio'
-- che il database accetta non possono piu' allontanarsi.
--
-- Effetto collaterale voluto: rientrano fra le prenotabili le partenze GIA'
-- INIZIATE ma non ancora finite (partita ieri, rientra domani). Prima le
-- nascondeva il confronto sulla data di inizio; per il database non sono
-- concluse, e chi si aggrega in corsa esiste davvero.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_wizard_get_viaggi_disponibili(p_azienda_id integer)
RETURNS TABLE(
    viaggio_id                 integer,
    viaggio_descrizione_breve  character varying,
    viaggio_descrizione_estesa text,
    viaggio_numero_giorni      integer,
    viaggio_numero_notti       integer,
    viaggio_link               character varying,
    nome_nazione               character varying
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        v.viaggio_id,
        v.viaggio_descrizione_breve,
        v.viaggio_descrizione_estesa,
        v.viaggio_numero_giorni,
        v.viaggio_numero_notti,
        v.viaggio_link,
        n.name::character varying AS nome_nazione
    FROM ana_viaggi v
    INNER JOIN ana_date_viaggi dv ON dv.viaggio_id_fk = v.viaggio_id
    LEFT JOIN eba_countries n     ON v.viaggio_nazione_fk = n.country_id
    WHERE v.azienda_id = p_azienda_id
      -- Una definizione sola di «conclusa», la stessa che rifiuta l'iscrizione.
      AND NOT fn_partenza_conclusa(dv.data_viaggio_id)
    ORDER BY v.viaggio_descrizione_breve;
END;
$$;

COMMENT ON FUNCTION fn_wizard_get_viaggi_disponibili(integer) IS
'I viaggi che il sito di iscrizione puo'' proporre: quelli con almeno una partenza non
conclusa secondo fn_partenza_conclusa — la stessa regola che decide se l''iscrizione
viene accettata. Cio'' che si mostra e cio'' che si accetta restano allineati.';
