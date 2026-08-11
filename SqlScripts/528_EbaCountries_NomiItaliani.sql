-- Nomi delle nazioni in italiano.
--
-- eba_countries arriva da una vecchia importazione Oracle e ha i nomi in inglese. Vanno mostrati
-- all'utente — nel filtro "clienti residenti in..." della newsletter, e ovunque servira' poi —
-- e "SWITZERLAND" in una tendina italiana e' fuori posto.
--
-- Si AGGIUNGE una colonna invece di sovrascrivere `name`: quel campo puo' essere gia' usato
-- altrove e il nome inglese resta comunque il riferimento internazionale. Chi mostra a video usa
-- name_it, chi confronta con sistemi esterni continua a usare name.
--
-- La chiave della traduzione e' iso_alpha2, non il nome: e' stabile, e' unica (verificato: 249
-- codici distinti su 249 righe) ed e' l'unica cosa che non cambia quando un paese si rinomina.
-- Appoggiarsi al nome inglese sarebbe stato fragile anche per un altro motivo: l'importazione
-- Oracle ha rovinato le lettere accentate — "CÙTE D'IVOIRE", "CURAÁAO", "SAINT BARTHÈLEMY" —
-- quindi un JOIN sul nome fallirebbe proprio sulle righe piu' difficili. I nomi italiani qui
-- sotto sono scritti correttamente.

ALTER TABLE eba_countries ADD COLUMN IF NOT EXISTS name_it VARCHAR(100);

COMMENT ON COLUMN eba_countries.name_it IS
'Nome della nazione in italiano, per la visualizzazione. Il riferimento internazionale resta `name`.';

UPDATE eba_countries c SET name_it = t.it
  FROM (VALUES
    ('AD','Andorra'), ('AE','Emirati Arabi Uniti'), ('AF','Afghanistan'),
    ('AG','Antigua e Barbuda'), ('AI','Anguilla'), ('AL','Albania'), ('AM','Armenia'),
    ('AO','Angola'), ('AQ','Antartide'), ('AR','Argentina'), ('AS','Samoa Americane'),
    ('AT','Austria'), ('AU','Australia'), ('AW','Aruba'), ('AX','Isole Åland'),
    ('AZ','Azerbaigian'), ('BA','Bosnia ed Erzegovina'), ('BB','Barbados'),
    ('BD','Bangladesh'), ('BE','Belgio'), ('BF','Burkina Faso'), ('BG','Bulgaria'),
    ('BH','Bahrein'), ('BI','Burundi'), ('BJ','Benin'), ('BL','Saint-Barthélemy'),
    ('BM','Bermuda'), ('BN','Brunei'), ('BO','Bolivia'),
    ('BQ','Caraibi Olandesi (Bonaire, Sint Eustatius e Saba)'), ('BR','Brasile'),
    ('BS','Bahamas'), ('BT','Bhutan'), ('BV','Isola Bouvet'), ('BW','Botswana'),
    ('BY','Bielorussia'), ('BZ','Belize'), ('CA','Canada'), ('CC','Isole Cocos (Keeling)'),
    ('CD','Repubblica Democratica del Congo'), ('CF','Repubblica Centrafricana'),
    ('CG','Repubblica del Congo'), ('CH','Svizzera'), ('CI','Costa d''Avorio'),
    ('CK','Isole Cook'), ('CL','Cile'), ('CM','Camerun'), ('CN','Cina'), ('CO','Colombia'),
    ('CR','Costa Rica'), ('CU','Cuba'), ('CV','Capo Verde'), ('CW','Curaçao'),
    ('CX','Isola di Natale'), ('CY','Cipro'), ('CZ','Cechia'), ('DE','Germania'),
    ('DJ','Gibuti'), ('DK','Danimarca'), ('DM','Dominica'), ('DO','Repubblica Dominicana'),
    ('DZ','Algeria'), ('EC','Ecuador'), ('EE','Estonia'), ('EG','Egitto'),
    ('EH','Sahara Occidentale'), ('ER','Eritrea'), ('ES','Spagna'), ('ET','Etiopia'),
    ('FI','Finlandia'), ('FJ','Figi'), ('FK','Isole Falkland (Malvine)'), ('FM','Micronesia'),
    ('FO','Isole Fær Øer'), ('FR','Francia'), ('GA','Gabon'), ('GB','Regno Unito'),
    ('GD','Grenada'), ('GE','Georgia'), ('GF','Guyana Francese'), ('GG','Guernsey'),
    ('GH','Ghana'), ('GI','Gibilterra'), ('GL','Groenlandia'), ('GM','Gambia'),
    ('GN','Guinea'), ('GP','Guadalupa'), ('GQ','Guinea Equatoriale'), ('GR','Grecia'),
    ('GS','Georgia del Sud e Isole Sandwich Australi'), ('GT','Guatemala'), ('GU','Guam'),
    ('GW','Guinea-Bissau'), ('GY','Guyana'), ('HK','Hong Kong'),
    ('HM','Isole Heard e McDonald'), ('HN','Honduras'), ('HR','Croazia'), ('HT','Haiti'),
    ('HU','Ungheria'), ('ID','Indonesia'), ('IE','Irlanda'), ('IL','Israele'),
    ('IM','Isola di Man'), ('IN','India'), ('IO','Territorio Britannico dell''Oceano Indiano'),
    ('IQ','Iraq'), ('IR','Iran'), ('IS','Islanda'), ('IT','Italia'), ('JE','Jersey'),
    ('JM','Giamaica'), ('JO','Giordania'), ('JP','Giappone'), ('KE','Kenya'),
    ('KG','Kirghizistan'), ('KH','Cambogia'), ('KI','Kiribati'), ('KM','Comore'),
    ('KN','Saint Kitts e Nevis'), ('KP','Corea del Nord'), ('KR','Corea del Sud'),
    ('KW','Kuwait'), ('KY','Isole Cayman'), ('KZ','Kazakistan'), ('LA','Laos'),
    ('LB','Libano'), ('LC','Santa Lucia'), ('LI','Liechtenstein'), ('LK','Sri Lanka'),
    ('LR','Liberia'), ('LS','Lesotho'), ('LT','Lituania'), ('LU','Lussemburgo'),
    ('LV','Lettonia'), ('LY','Libia'), ('MA','Marocco'), ('MC','Monaco'), ('MD','Moldavia'),
    ('ME','Montenegro'), ('MF','Saint-Martin'), ('MG','Madagascar'), ('MH','Isole Marshall'),
    ('MK','Macedonia del Nord'), ('ML','Mali'), ('MM','Myanmar (Birmania)'), ('MN','Mongolia'),
    ('MO','Macao'), ('MP','Isole Marianne Settentrionali'), ('MQ','Martinica'),
    ('MR','Mauritania'), ('MS','Montserrat'), ('MT','Malta'), ('MU','Mauritius'),
    ('MV','Maldive'), ('MW','Malawi'), ('MX','Messico'), ('MY','Malaysia'),
    ('MZ','Mozambico'), ('NA','Namibia'), ('NC','Nuova Caledonia'), ('NE','Niger'),
    ('NF','Isola Norfolk'), ('NG','Nigeria'), ('NI','Nicaragua'), ('NL','Paesi Bassi'),
    ('NO','Norvegia'), ('NP','Nepal'), ('NR','Nauru'), ('NU','Niue'), ('NZ','Nuova Zelanda'),
    ('OM','Oman'), ('PA','Panama'), ('PE','Perù'), ('PF','Polinesia Francese'),
    ('PG','Papua Nuova Guinea'), ('PH','Filippine'), ('PK','Pakistan'), ('PL','Polonia'),
    ('PM','Saint-Pierre e Miquelon'), ('PN','Isole Pitcairn'), ('PR','Porto Rico'),
    ('PS','Palestina'), ('PT','Portogallo'), ('PW','Palau'), ('PY','Paraguay'), ('QA','Qatar'),
    ('RE','Riunione'), ('RO','Romania'), ('RS','Serbia'), ('RU','Russia'), ('RW','Ruanda'),
    ('SA','Arabia Saudita'), ('SB','Isole Salomone'), ('SC','Seychelles'), ('SD','Sudan'),
    ('SE','Svezia'), ('SG','Singapore'),
    ('SH','Sant''Elena, Ascensione e Tristan da Cunha'), ('SI','Slovenia'),
    ('SJ','Svalbard e Jan Mayen'), ('SK','Slovacchia'), ('SL','Sierra Leone'),
    ('SM','San Marino'), ('SN','Senegal'), ('SO','Somalia'), ('SR','Suriname'),
    ('SS','Sud Sudan'), ('ST','São Tomé e Príncipe'), ('SV','El Salvador'),
    ('SX','Sint Maarten'), ('SY','Siria'), ('SZ','Eswatini (Swaziland)'),
    ('TC','Isole Turks e Caicos'), ('TD','Ciad'), ('TF','Terre Australi Francesi'),
    ('TG','Togo'), ('TH','Thailandia'), ('TJ','Tagikistan'), ('TK','Tokelau'),
    ('TL','Timor Est'), ('TM','Turkmenistan'), ('TN','Tunisia'), ('TO','Tonga'),
    ('TR','Turchia'), ('TT','Trinidad e Tobago'), ('TV','Tuvalu'), ('TW','Taiwan'),
    ('TZ','Tanzania'), ('UA','Ucraina'), ('UG','Uganda'),
    ('UM','Isole Minori Esterne degli Stati Uniti'), ('US','Stati Uniti d''America'),
    ('UY','Uruguay'), ('UZ','Uzbekistan'), ('VA','Città del Vaticano'),
    ('VC','Saint Vincent e Grenadine'), ('VE','Venezuela'), ('VG','Isole Vergini Britanniche'),
    ('VI','Isole Vergini Americane'), ('VN','Vietnam'), ('VU','Vanuatu'),
    ('WF','Wallis e Futuna'), ('WS','Samoa'), ('YE','Yemen'), ('YT','Mayotte'),
    ('ZA','Sudafrica'), ('ZM','Zambia'), ('ZW','Zimbabwe')
  ) AS t(iso, it)
 WHERE c.iso_alpha2 = t.iso;

-- Nessuna nazione deve restare senza nome italiano: una riga scoperta diventerebbe una voce vuota
-- nella tendina dei filtri, e non lo si scoprirebbe prima di vederla a video.
DO $$
DECLARE v_mancanti INTEGER; v_elenco TEXT;
BEGIN
    SELECT count(*), string_agg(iso_alpha2 || ' (' || name || ')', ', ')
      INTO v_mancanti, v_elenco
      FROM eba_countries WHERE name_it IS NULL;

    IF v_mancanti > 0 THEN
        RAISE EXCEPTION 'Restano % nazioni senza nome italiano: %', v_mancanti, v_elenco;
    END IF;

    RAISE NOTICE 'Tradotte tutte le % nazioni.', (SELECT count(*) FROM eba_countries);
END $$;
