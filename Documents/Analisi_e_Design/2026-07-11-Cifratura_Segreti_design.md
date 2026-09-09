# Cifratura segreti (`_enc`) — design

> Hardening pre-release. Sostituisce i campi `_enc` FINTI (JSONB `{"value":plaintext}`) e la
> `ana_aziende.claude_api_key` in chiaro con **cifratura reale via pgcrypto**. Validato con Adriano (2026-07-11).

## Decisioni
- **Approccio A — pgcrypto nel DB, master key dall'app.** `pgp_sym_encrypt(plaintext, key)` / `pgp_sym_decrypt(col, key)`. La cifra/decifra resta nelle funzioni DB (DB-first); i service passano la key come **parametro bound** (non loggato; TLS su Supabase). pgcrypto è già installato.
- **Master key**: variabile d'ambiente **`GV_SECRET_KEY`** (stringa forte, es. base64 di 32 byte), **fuori da git**. I segreti cifrati vivono nel DB Supabase **condiviso** → tutte le installazioni devono avere la **stessa** key (per questo NON si usa SecureStorage per-dispositivo). Un `SecretKeyProvider` centrale la legge; se assente → errore chiaro (fail-fast) quando si opera su un segreto.
- **Scope**: SMTP (`ana_aziende_smtp.password_enc`, `inbound_password_enc`), ESP (`ana_aziende_esp.api_key_enc`), Claude (`ana_aziende.claude_api_key`). Stesso formato applicato a `web_pagamenti_config.stripe_*_enc` (predisposto Fase 4, nessun valore). Esclusi: **Geoapify** (deciso: free/rigenerabile), `sys_redis_endpoints` (infra, invariato).

## Schema
- Colonne `_enc` da `jsonb {value}` → **`bytea`** (output pgp). `ana_aziende`: +`claude_api_key_enc bytea`, drop `claude_api_key text`.
- **Migrazione a freddo**: i valori attuali sono FINTI → il cambio tipo azzera i valori (`USING NULL`). Nessuna key nello script. I (pochi, finti) segreti vanno **re-inseriti** dalle form dopo il rilascio della cifratura → nota nel Go-Live. In PROD non esistevano segreti reali cifrati.

## Funzioni DB (SqlScripts/475)
- Claude: `fn_ana_aziende_claude_key_set(p_azienda, p_key_plain, p_master)` → `pgp_sym_encrypt`; `fn_ana_aziende_claude_key_get(p_azienda, p_master)` → `pgp_sym_decrypt`. (rimpiazza 463)
- SMTP: `fn_get_smtp_config_for_email(p_azienda, p_master)` decifra `password_enc`/`inbound_password_enc`. Scrittura: `AziendaSmtpService` usa `pgp_sym_encrypt(@pwd::text, @master::text)` nell'INSERT/UPDATE inline (già inline oggi).
- ESP: `fn_ana_aziende_esp_*` (443) aggiornata a cifrare `api_key_enc` con la master key (nessun consumer C# ancora → pronta per quando ESP verrà wired).

## C#
- **`SecretKeyProvider`** (`Services/Security/`): legge `GV_SECRET_KEY` (env). `string GetKey()` → throw `InvalidOperationException` se mancante. Registrato singleton in MauiProgram.
- `AziendaSmtpService`: INSERT/UPDATE `password_enc`/`inbound_password_enc` → `pgp_sym_encrypt(@pwd::text, @master::text)`; read via `fn_get_smtp_config_for_email(@az, @master)`.
- `SmtpEmailSender`: `fn_get_smtp_config_for_email(@AziendaId, @master)`.
- `WebTraduzioneOrchestratorService`: `SetClaudeKeyAsync`/`GetClaudeKeyAsync` → passano la master key alle nuove funzioni.

## Test / verifica
- Salvo una password SMTP → nel DB `password_enc` è **bytea non leggibile**; l'invio email la decifra correttamente.
- Salvo/uso la chiave Claude → cifrata; traduzione funziona.
- Con `GV_SECRET_KEY` errata/assente → operazioni sui segreti falliscono con errore chiaro (no crash silenzioso).

## Go-Live
- Impostare `GV_SECRET_KEY` (stessa su tutte le installazioni) prima di caricare segreti reali.
- Re-inserire i segreti (finti azzerati dalla migrazione) dalle form dopo il deploy dello script 475.
