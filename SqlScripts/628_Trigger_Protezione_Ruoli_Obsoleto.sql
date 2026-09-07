-- ============================================================================
-- 628 — via trg_user_roles_delete_protection, che proteggeva una colonna sparita
--
-- ANTEFATTO. Il 2026-09-07, pulendo le funzioni senza chiamanti, questo trigger
-- era stato tenuto da parte come «una protezione mai agganciata»: sembrava che
-- cancellando un ruolo gli utenti restassero a puntare nel vuoto. Adriano ha
-- chiesto di sistemarlo prima dei test, giustamente.
--
-- ⚠️ MISURANDO, LA LACUNA NON C'ERA. Il legame utente-ruolo non passa da
-- `app_users.role_id` — quella colonna NON ESISTE, ne' in locale ne' su PROD —
-- ma da `app_user_role_map.role_code`. E quel legame e' gia' protetto:
--
--   app_user_role_map.role_code  -> user_roles(role_code)  ON DELETE RESTRICT
--   sys_menu_role_grants.role_code -> user_roles(role_code) ON DELETE RESTRICT
--
-- Verificato per esperimento su transazione annullata: cancellare un ruolo
-- assegnato viene RIFIUTATO. Zero righe orfane in entrambi gli ambienti.
--
-- Il trigger, quindi, non era una protezione mancante: era il residuo di un
-- disegno precedente, scritto su una colonna poi rimossa. Se qualcuno lo avesse
-- agganciato, sarebbe fallito alla prima cancellazione — e nel frattempo la sua
-- esistenza faceva credere che la protezione vera non ci fosse. Ha ingannato me;
-- il prossimo lo leggerebbe allo stesso modo.
--
-- ⚠️ Resta scoperta una cosa sola, ed e' il MESSAGGIO: il rifiuto arriva come
--    «violates foreign key constraint app_user_role_map_role_code_fkey»,
-- che non dice a chi legge quale ruolo, ne' chi lo sta usando. Oggi non ha
-- conseguenze pratiche — i ruoli non si cancellano da nessuna interfaccia e non
-- esiste alcuna funzione che lo faccia: si puo' fare solo a mano da psql, dove
-- chi legge sa interpretarlo. Quando si costruira' la gestione dei ruoli, il
-- rifiuto dovra' spiegare.
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS public.trg_user_roles_delete_protection();

DO $verifica$
DECLARE v_protezioni integer;
BEGIN
    -- Non basta che il trigger sia sparito: deve restare in piedi la protezione vera.
    SELECT count(*) INTO v_protezioni
    FROM pg_constraint
    WHERE contype = 'f'
      AND confrelid = 'public.user_roles'::regclass
      AND confdeltype = 'r';   -- 'r' = RESTRICT

    IF v_protezioni < 2 THEN
        RAISE EXCEPTION '628: mi aspettavo almeno 2 vincoli RESTRICT verso user_roles, ne trovo %.',
                        v_protezioni;
    END IF;
    IF to_regproc('public.trg_user_roles_delete_protection') IS NOT NULL THEN
        RAISE EXCEPTION '628: il trigger obsoleto e ancora presente.';
    END IF;

    RAISE NOTICE '628: trigger obsoleto rimosso; i % vincoli RESTRICT su user_roles restano.',
                 v_protezioni;
END
$verifica$;

COMMIT;
