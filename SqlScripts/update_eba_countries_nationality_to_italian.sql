-- Script: update_eba_countries_nationality_to_italian.sql
-- Description: Converte tutte le nazionalità dalla lingua inglese all'italiano
-- Date: 2026-03-16
-- Author: Sistema GestioneViaggi

-- Backup consigliato prima dell'esecuzione:
-- pg_dump -U postgres -d gestione_viaggi -t eba_countries > backup_eba_countries_$(date +%Y%m%d).sql

BEGIN;

UPDATE eba_countries
SET nationality = CASE nationality
    -- A
    WHEN 'Afghan' THEN 'AFGHANA'
    WHEN 'Aland Island' THEN 'ALANDESE'
    WHEN 'Albanian' THEN 'ALBANESE'
    WHEN 'Algerian' THEN 'ALGERINA'
    WHEN 'American' THEN 'AMERICANA'
    WHEN 'American Samoan' THEN 'SAMOANA AMERICANA'
    WHEN 'Andorran' THEN 'ANDORRANA'
    WHEN 'Angolan' THEN 'ANGOLANA'
    WHEN 'Anguillan' THEN 'ANGUILLANA'
    WHEN 'Antarctic' THEN 'ANTARTICA'
    WHEN 'Antiguan or Barbudan' THEN 'ANTIGUANO-BARBUDANA'
    WHEN 'Argentine' THEN 'ARGENTINA'
    WHEN 'Armenian' THEN 'ARMENA'
    WHEN 'Aruban' THEN 'ARUBANA'
    WHEN 'Ascension and Tristan da Cunha' THEN 'DI ASCENSION E TRISTAN DA CUNHA'
    WHEN 'Australian' THEN 'AUSTRALIANA'
    WHEN 'Austrian' THEN 'AUSTRIACA'
    WHEN 'Azerbaijani' THEN 'AZERA'

    -- B
    WHEN 'Bahamian' THEN 'BAHAMENSE'
    WHEN 'Bahraini' THEN 'BAHRAINITA'
    WHEN 'Bangladeshi' THEN 'BANGLADESE'
    WHEN 'Barbadian' THEN 'BARBADIANA'
    WHEN 'BarthÈlemois' THEN 'DI SAN BARTOLOMEO'
    WHEN 'Basotho' THEN 'BASOTHO'
    WHEN 'Belarusian' THEN 'BIELORUSSA'
    WHEN 'Belgian' THEN 'BELGA'
    WHEN 'Belizean' THEN 'BELIZIANA'
    WHEN 'Beninese' THEN 'BENINESE'
    WHEN 'Bermudian' THEN 'BERMUDIANA'
    WHEN 'Bhutanese' THEN 'BHUTANESE'
    WHEN 'BIOT' THEN 'TERRITORIO BRITANNICO OCEANO INDIANO'
    WHEN 'Bissau-Guinean' THEN 'GUINEANO-BISSAU'
    WHEN 'Bolivian' THEN 'BOLIVIANA'
    WHEN 'Bosnian or Herzegovinian' THEN 'BOSNIACA'
    WHEN 'Bouvet Island' THEN 'ISOLA BOUVET'
    WHEN 'Brazilian' THEN 'BRASILIANA'
    WHEN 'British' THEN 'BRITANNICA'
    WHEN 'British Virgin Island' THEN 'VERGINE BRITANNICA'
    WHEN 'Bruneian' THEN 'DEL BRUNEI'
    WHEN 'Bulgarian' THEN 'BULGARA'
    WHEN 'BurkinabÈ' THEN 'BURKINABÈ'
    WHEN 'Burmese' THEN 'BIRMANA'
    WHEN 'Burundian' THEN 'BURUNDESE'

    -- C
    WHEN 'Cabo Verdean' THEN 'CAPOVERDIANA'
    WHEN 'Cambodian' THEN 'CAMBOGIANA'
    WHEN 'Cameroonian' THEN 'CAMERUNESE'
    WHEN 'Canadian' THEN 'CANADESE'
    WHEN 'Caymanian' THEN 'DELLE ISOLE CAYMAN'
    WHEN 'Central African' THEN 'CENTRAFRICANA'
    WHEN 'Chadian' THEN 'CIADIANA'
    WHEN 'Channel Island' THEN 'DELLE ISOLE DEL CANALE'
    WHEN 'Chilean' THEN 'CILENA'
    WHEN 'Chinese' THEN 'CINESE'
    WHEN 'Christmas Island' THEN 'ISOLA CHRISTMAS'
    WHEN 'Cocos Island' THEN 'ISOLE COCOS'
    WHEN 'Colombian' THEN 'COLOMBIANA'
    WHEN 'Comoran' THEN 'COMORIANA'
    WHEN 'Congolese' THEN 'CONGOLESE'
    WHEN 'Cook Island' THEN 'ISOLE COOK'
    WHEN 'Costa Rican' THEN 'COSTARICANA'
    WHEN 'Croatian' THEN 'CROATA'
    WHEN 'Cuban' THEN 'CUBANA'
    WHEN 'CuraÁaoan' THEN 'DI CURAÇAO'
    WHEN 'Cypriot' THEN 'CIPRIOTA'
    WHEN 'Czech' THEN 'CECA'

    -- D
    WHEN 'Danish' THEN 'DANESE'
    WHEN 'Djiboutian' THEN 'GIBUTIANA'
    WHEN 'Dominican' THEN 'DOMINICANA'
    WHEN 'Dutch' THEN 'OLANDESE'

    -- E
    WHEN 'Ecuadorian' THEN 'ECUADORIANA'
    WHEN 'Egyptian' THEN 'EGIZIANA'
    WHEN 'Emirati' THEN 'EMIRATINA'
    WHEN 'Equatorial Guinean' THEN 'DELLA GUINEA EQUATORIALE'
    WHEN 'Eritrean' THEN 'ERITREA'
    WHEN 'Estonian' THEN 'ESTONE'
    WHEN 'Ethiopian' THEN 'ETIOPE'

    -- F
    WHEN 'Falkland Island' THEN 'ISOLE FALKLAND'
    WHEN 'Faroese' THEN 'FAROESE'
    WHEN 'Fijian' THEN 'FIGIANA'
    WHEN 'Filipino' THEN 'FILIPPINA'
    WHEN 'Finnish' THEN 'FINLANDESE'
    WHEN 'French' THEN 'FRANCESE'
    WHEN 'French Guianese' THEN 'GUYANA FRANCESE'
    WHEN 'French Polynesian' THEN 'POLINESIA FRANCESE'
    WHEN 'French Southern Territories' THEN 'TERRE AUSTRALI FRANCESI'

    -- G
    WHEN 'Gabonese' THEN 'GABONESE'
    WHEN 'Gambian' THEN 'GAMBIANA'
    WHEN 'Georgian' THEN 'GEORGIANA'
    WHEN 'German' THEN 'TEDESCA'
    WHEN 'Ghanaian' THEN 'GHANESE'
    WHEN 'Gibraltar' THEN 'GIBILTERRA'
    WHEN 'Greek' THEN 'GRECA'
    WHEN 'Greenlandic' THEN 'GROENLANDESE'
    WHEN 'Grenadian' THEN 'GRENADINA'
    WHEN 'Guadeloupe' THEN 'GUADALUPA'
    WHEN 'Guamanian' THEN 'GUAMENSE'
    WHEN 'Guatemalan' THEN 'GUATEMALTECA'
    WHEN 'Guinean' THEN 'GUINEANA'
    WHEN 'Guyanese' THEN 'GUYANESE'

    -- H
    WHEN 'Haitian' THEN 'HAITIANA'
    WHEN 'Heard Island or McDonald Islands' THEN 'ISOLE HEARD E MCDONALD'
    WHEN 'Honduran' THEN 'HONDUREGNA'
    WHEN 'Hong Kong' THEN 'HONG KONG'
    WHEN 'Hungarian' THEN 'UNGHERESE'

    -- I
    WHEN 'Icelandic' THEN 'ISLANDESE'
    WHEN 'I-Kiribati' THEN 'KIRIBATIANA'
    WHEN 'Indian' THEN 'INDIANA'
    WHEN 'Indonesian' THEN 'INDONESIANA'
    WHEN 'Iranian' THEN 'IRANIANA'
    WHEN 'Iraqi' THEN 'IRACHENA'
    WHEN 'Irish' THEN 'IRLANDESE'
    WHEN 'Israeli' THEN 'ISRAELIANA'
    WHEN 'Italian' THEN 'ITALIANA'
    WHEN 'Ivorian' THEN 'IVORIANA'

    -- J
    WHEN 'Jamaican' THEN 'GIAMAICANA'
    WHEN 'Japanese' THEN 'GIAPPONESE'
    WHEN 'Jordanian' THEN 'GIORDANA'

    -- K
    WHEN 'Kazakhstani' THEN 'KAZAKA'
    WHEN 'Kenyan' THEN 'KENIOTA'
    WHEN 'Kittitian or Nevisian' THEN 'DI SAINT KITTS E NEVIS'
    WHEN 'Kuwaiti' THEN 'KUWAITIANA'
    WHEN 'Kyrgyzstani' THEN 'KIRGHISA'

    -- L
    WHEN 'Lao' THEN 'LAOTIANA'
    WHEN 'Latvian' THEN 'LETTONE'
    WHEN 'Lebanese' THEN 'LIBANESE'
    WHEN 'Liberian' THEN 'LIBERIANA'
    WHEN 'Libyan' THEN 'LIBICA'
    WHEN 'Liechtenstein' THEN 'LIECHTENSTEINIANA'
    WHEN 'Lithuanian' THEN 'LITUANA'
    WHEN 'Luxembourg' THEN 'LUSSEMBURGHESE'

    -- M
    WHEN 'Macanese' THEN 'MACANESE'
    WHEN 'Macedonian' THEN 'MACEDONE'
    WHEN 'Mahoran' THEN 'MAHORIANA'
    WHEN 'Malagasy' THEN 'MALGASCIA'
    WHEN 'Malawian' THEN 'MALAWIANA'
    WHEN 'Malaysian' THEN 'MALESE'
    WHEN 'Maldivian' THEN 'MALDIVIANA'
    WHEN 'Malian' THEN 'MALIANA'
    WHEN 'Maltese' THEN 'MALTESE'
    WHEN 'Manx' THEN 'MANNESE'
    WHEN 'Marshallese' THEN 'MARSHALLESE'
    WHEN 'Martiniquais' THEN 'MARTINICANA'
    WHEN 'Mauritanian' THEN 'MAURITANA'
    WHEN 'Mauritian' THEN 'MAURIZIANA'
    WHEN 'Mexican' THEN 'MESSICANA'
    WHEN 'Micronesian' THEN 'MICRONESIANA'
    WHEN 'Moldovan' THEN 'MOLDAVA'
    WHEN 'MonÈgasque' THEN 'MONEGASCA'
    WHEN 'Mongolian' THEN 'MONGOLA'
    WHEN 'Montenegrin' THEN 'MONTENEGRINA'
    WHEN 'Montserratian' THEN 'MONTSERRATIANA'
    WHEN 'Moroccan' THEN 'MAROCCHINA'
    WHEN 'Motswana' THEN 'BOTSWANA'
    WHEN 'Mozambican' THEN 'MOZAMBICANA'

    -- N
    WHEN 'Namibian' THEN 'NAMIBIANA'
    WHEN 'Nauruan' THEN 'NAURUANA'
    WHEN 'Nepali' THEN 'NEPALESE'
    WHEN 'New Caledonian' THEN 'NEOCALEDONIANA'
    WHEN 'New Zealander' THEN 'NEOZELANDESE'
    WHEN 'Nicaraguan' THEN 'NICARAGUENSE'
    WHEN 'Nigerian' THEN 'NIGERIANA'
    WHEN 'Nigerien' THEN 'NIGERINA'
    WHEN 'Niuean' THEN 'NIUEANA'
    WHEN 'Ni-Vanuatu' THEN 'VANUATUANA'
    WHEN 'Norfolk Island' THEN 'ISOLA NORFOLK'
    WHEN 'Northern Marianan' THEN 'MARIANNE SETTENTRIONALI'
    WHEN 'North Korean' THEN 'NORDCOREANA'
    WHEN 'Norwegian' THEN 'NORVEGESE'

    -- O
    WHEN 'Omani' THEN 'OMANITA'

    -- P
    WHEN 'Pakistani' THEN 'PAKISTANA'
    WHEN 'Palauan' THEN 'PALAUIANA'
    WHEN 'Palestinian' THEN 'PALESTINESE'
    WHEN 'Panamanian' THEN 'PANAMENSE'
    WHEN 'Papua New Guinean' THEN 'PAPUANA'
    WHEN 'Paraguayan' THEN 'PARAGUAIANA'
    WHEN 'Peruvian' THEN 'PERUVIANA'
    WHEN 'Pitcairn Island' THEN 'ISOLE PITCAIRN'
    WHEN 'Polish' THEN 'POLACCA'
    WHEN 'Portuguese' THEN 'PORTOGHESE'
    WHEN 'Puerto Rican' THEN 'PORTORICANA'

    -- Q
    WHEN 'Qatari' THEN 'QATARIOTA'

    -- R
    WHEN 'RÈunionese' THEN 'RIUNIONESE'
    WHEN 'Romanian' THEN 'RUMENA'
    WHEN 'Russian' THEN 'RUSSA'
    WHEN 'Rwandan' THEN 'RUANDESE'

    -- S
    WHEN 'Sahrawi' THEN 'SAHARAWI'
    WHEN 'Saint Lucian' THEN 'SANTALUCIANA'
    WHEN 'Saint-Martinoise' THEN 'DI SAINT MARTIN'
    WHEN 'Saint-Pierrais or Miquelonnais' THEN 'DI SAINT PIERRE E MIQUELON'
    WHEN 'Saint Vincentian' THEN 'SANTVINCENZIANA'
    WHEN 'Salvadoran' THEN 'SALVADOREGNA'
    WHEN 'Sammarinese' THEN 'SAMMARINESE'
    WHEN 'Samoan' THEN 'SAMOANA'
    WHEN 'Saudi' THEN 'SAUDITA'
    WHEN 'Senegalese' THEN 'SENEGALESE'
    WHEN 'Serbian' THEN 'SERBA'
    WHEN 'Seychellois' THEN 'SEICELLESE'
    WHEN 'Sierra Leonean' THEN 'SIERRALEONESE'
    WHEN 'Singaporean' THEN 'SINGAPORIANA'
    WHEN 'Sint Eustatius and Saba' THEN 'SINT EUSTATIUS E SABA'
    WHEN 'Sint Maarten' THEN 'SINT MAARTEN'
    WHEN 'Slovak' THEN 'SLOVACCA'
    WHEN 'Slovenian' THEN 'SLOVENA'
    WHEN 'Solomon Island' THEN 'SALOMONESE'
    WHEN 'Somali' THEN 'SOMALA'
    WHEN 'S„o TomÈan' THEN 'SANTOMENSE'
    WHEN 'South African' THEN 'SUDAFRICANA'
    WHEN 'South Georgia or South Sandwich Islands' THEN 'GEORGIA DEL SUD E SANDWICH AUSTRALI'
    WHEN 'South Korean' THEN 'SUDCOREANA'
    WHEN 'South Sudanese' THEN 'SUDSUDANESE'
    WHEN 'Spanish' THEN 'SPAGNOLA'
    WHEN 'Sri Lankan' THEN 'SRILANKESE'
    WHEN 'Sudanese' THEN 'SUDANESE'
    WHEN 'Surinamese' THEN 'SURINAMESE'
    WHEN 'Svalbard' THEN 'SVALBARD'
    WHEN 'Swazi' THEN 'SWAZILANDESE'
    WHEN 'Swedish' THEN 'SVEDESE'
    WHEN 'Swiss' THEN 'SVIZZERA'
    WHEN 'Syrian' THEN 'SIRIANA'

    -- T
    WHEN 'Taiwanese' THEN 'TAIWANESE'
    WHEN 'Tajikistani' THEN 'TAGIKA'
    WHEN 'Tanzanian' THEN 'TANZANIANA'
    WHEN 'Thai' THEN 'THAILANDESE'
    WHEN 'Timorese' THEN 'TIMORESE'
    WHEN 'Togolese' THEN 'TOGOLESE'
    WHEN 'Tokelauan' THEN 'TOKELAUIANA'
    WHEN 'Tongan' THEN 'TONGANA'
    WHEN 'Trinidadian or Tobagonian' THEN 'TRINIDADIANA'
    WHEN 'Tunisian' THEN 'TUNISINA'
    WHEN 'Turkish' THEN 'TURCA'
    WHEN 'Turkmen' THEN 'TURKMENA'
    WHEN 'Turks and Caicos Island' THEN 'TURKS E CAICOS'
    WHEN 'Tuvaluan' THEN 'TUVALUANA'

    -- U
    WHEN 'Ugandan' THEN 'UGANDESE'
    WHEN 'Ukrainian' THEN 'UCRAINA'
    WHEN 'Uruguayan' THEN 'URUGUAIANA'
    WHEN 'U.S. Virgin Island' THEN 'VERGINE AMERICANA'
    WHEN 'Uzbekistani' THEN 'UZBEKA'

    -- V
    WHEN 'Vatican' THEN 'VATICANA'
    WHEN 'Venezuelan' THEN 'VENEZUELANA'
    WHEN 'Vietnamese' THEN 'VIETNAMITA'

    -- W
    WHEN 'Wallis and Futuna' THEN 'WALLIS E FUTUNA'

    -- Y
    WHEN 'Yemeni' THEN 'YEMENITA'

    -- Z
    WHEN 'Zambian' THEN 'ZAMBIANA'
    WHEN 'Zimbabwean' THEN 'ZIMBABWESE'

    -- Lascia invariato se non trovato nel mapping (non dovrebbe mai succedere)
    ELSE nationality
END;

-- Verifica del numero di righe aggiornate
SELECT COUNT(*) AS rows_updated FROM eba_countries;

COMMIT;

-- Query di verifica post-aggiornamento
SELECT DISTINCT nationality FROM eba_countries ORDER BY nationality LIMIT 20;
