# 🐘 Guida: Collegamento a PostgreSQL su Docker

**Progetto**: Gestione Viaggi Offroad
**Database**: PostgreSQL 17.5
**Piattaforma**: Docker (Linux ARM64 su Mac)
**Ultimo aggiornamento**: 05/12/2025

---

## 📋 Informazioni di Connessione

### Credenziali Database

| Parametro | Valore |
|-----------|--------|
| **Host (Mac locale)** | `127.0.0.1` (localhost) |
| **Porta** | `5432` |
| **Database** | `gestione_viaggi` |
| **Username** | `postgres` (superuser) |
| **Password** | `postgres` |
| **Versione PostgreSQL** | 17.5 (Debian 17.5-1.pgdg120+1) |
| **Volume Docker** | `db_gestioneviaggi_postgres_data` |
| **Container Name** | `postgres_db` |
