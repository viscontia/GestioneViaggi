
SELECT 'CHECK_CLIENTI' as check_type, cliente_id, cliente_cognome, cliente_nome, azienda_fk FROM ana_clienti WHERE cliente_id IN (2189, 3673);

SELECT 'VIAGGI_2189' as check_type, m.cliente_id_fk, v.viaggio_id, d.data_viaggio_data_inizio, v.azienda_id 
FROM mov_clienti_viaggi m
JOIN ana_viaggi v ON m.viaggio_id_fk = v.viaggio_id
LEFT JOIN ana_date_viaggi d ON m.data_viaggio_id_fk = d.data_viaggio_id
WHERE m.cliente_id_fk = 2189;

SELECT 'VIAGGI_3673' as check_type, m.cliente_id_fk, v.viaggio_id, d.data_viaggio_data_inizio, v.azienda_id 
FROM mov_clienti_viaggi m
JOIN ana_viaggi v ON m.viaggio_id_fk = v.viaggio_id
LEFT JOIN ana_date_viaggi d ON m.data_viaggio_id_fk = d.data_viaggio_id
WHERE m.cliente_id_fk = 3673;

SELECT 'ALLOGGI_2189' as check_type, ma.mov_clienti_alloggio_pk, v.viaggio_id, d.data_viaggio_data_inizio, v.azienda_id 
FROM mov_clienti_alloggi ma
JOIN ana_viaggi v ON ma.viaggio_id_fk = v.viaggio_id
LEFT JOIN ana_date_viaggi d ON ma.data_viaggio_id_fk = d.data_viaggio_id
WHERE 2189 IN (cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk);

SELECT 'ALLOGGI_3673' as check_type, ma.mov_clienti_alloggio_pk, v.viaggio_id, d.data_viaggio_data_inizio, v.azienda_id 
FROM mov_clienti_alloggi ma
JOIN ana_viaggi v ON ma.viaggio_id_fk = v.viaggio_id
LEFT JOIN ana_date_viaggi d ON ma.data_viaggio_id_fk = d.data_viaggio_id
WHERE 3673 IN (cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk);
