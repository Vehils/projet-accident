-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 4 : nettoyage et création des 4 tables propres
-- ============================================================
-- Principe : on ne modifie jamais les tables brut_*.
-- On crée 4 tables propres (bons types, noms de colonnes
-- harmonisés, clés primaires et étrangères) et on les remplit
-- avec INSERT ... SELECT en convertissant les données.
--
--   accident  (PK Num_Acc)
--   lieu      (PK + FK Num_Acc → accident)      1 ligne par accident
--   vehicule  (PK id_vehicule, FK Num_Acc → accident)
--   usager    (PK id_usager_cle, FK Num_Acc → accident,
--                                FK id_vehicule → vehicule)
--
-- Règles de nettoyage communes :
--   * codes : tout ce qui n'est pas un nombre (−1 = non renseigné,
--     cellule vide, valeur parasite) → NULL
--   * espaces en trop retirés (TRIM)
--   * virgule décimale remplacée par un point (coordonnées)
--   * espaces insécables retirés des identifiants
--     (ex. "155 975 242" → 155975242)
--
-- À exécuter PARTIE PAR PARTIE, en vérifiant le contrôle
-- à la fin de chaque partie avant de passer à la suivante.
-- Nécessite MySQL 8 (fonction REGEXP_REPLACE).
-- ============================================================

USE accidents;

-- ------------------------------------------------------------
-- PARTIE 0 : vérification de la version + remise à zéro
-- ------------------------------------------------------------
SELECT VERSION();   -- doit commencer par 8.

-- Supprime les tables propres si on relance le script
-- (ordre inverse des clés étrangères). Les tables brut_* ne sont pas touchées.
DROP TABLE IF EXISTS usager;
DROP TABLE IF EXISTS vehicule;
DROP TABLE IF EXISTS lieu;
DROP TABLE IF EXISTS accident;


-- ------------------------------------------------------------
-- PARTIE 1 : table ACCIDENT (depuis brut_caract)
-- ------------------------------------------------------------
CREATE TABLE accident (
  Num_Acc           BIGINT UNSIGNED PRIMARY KEY,
  date_accident     DATE        NOT NULL,
  annee             SMALLINT    NOT NULL,
  mois              TINYINT     NOT NULL,
  heure             TIME,
  heure_num         TINYINT,          -- heure seule (0-23), pratique pour les graphiques
  luminosite        TINYINT,          -- lum
  agglomeration     TINYINT,          -- agg : 1 = hors agglomération, 2 = en agglomération
  intersection      TINYINT,          -- int
  conditions_atmo   TINYINT,          -- atm
  type_collision    TINYINT,          -- col
  departement       VARCHAR(3),       -- dep (harmonisé sur 2 caractères minimum)
  commune_insee     VARCHAR(5),       -- com
  adresse           VARCHAR(255),     -- adr
  latitude          DECIMAL(10,7),
  longitude         DECIMAL(10,7),
  qualite_coord     VARCHAR(20)       -- ok / inversées corrigées / invalides
);

INSERT INTO accident
SELECT
  CAST(t.Num_Acc AS UNSIGNED),
  STR_TO_DATE(CONCAT(TRIM(t.an), '-', TRIM(t.mois), '-', TRIM(t.jour)), '%Y-%m-%d'),
  CAST(TRIM(t.an)   AS UNSIGNED),
  CAST(TRIM(t.mois) AS UNSIGNED),
  STR_TO_DATE(TRIM(t.hrmn), '%H:%i'),
  CAST(LEFT(TRIM(t.hrmn), 2) AS UNSIGNED),
  IF(TRIM(t.lum) REGEXP '^[0-9]+$', TRIM(t.lum), NULL),
  IF(TRIM(t.agg) REGEXP '^[0-9]+$', TRIM(t.agg), NULL),
  IF(TRIM(t.`int`) REGEXP '^[0-9]+$', TRIM(t.`int`), NULL),
  IF(TRIM(t.atm) REGEXP '^[0-9]+$', TRIM(t.atm), NULL),
  IF(TRIM(t.col) REGEXP '^[0-9]+$', TRIM(t.col), NULL),
  -- 2019 : départements écrits "1" au lieu de "01" → on ajoute le zéro
  CASE WHEN TRIM(t.dep) REGEXP '^[0-9]$' THEN LPAD(TRIM(t.dep), 2, '0')
       ELSE TRIM(t.dep) END,
  TRIM(t.com),
  NULLIF(NULLIF(TRIM(t.adr), ''), 'N/A'),
  -- Coordonnées : on vérifie qu'un point de métropole tombe bien en métropole
  CASE
    WHEN t.outre_mer = 1                                                    THEN t.lat_n
    WHEN t.lat_n BETWEEN 41 AND 51.2 AND t.lon_n BETWEEN -5.5 AND 9.7       THEN t.lat_n
    WHEN t.lon_n BETWEEN 41 AND 51.2 AND t.lat_n BETWEEN -5.5 AND 9.7       THEN t.lon_n  -- inversées
    ELSE NULL END,
  CASE
    WHEN t.outre_mer = 1                                                    THEN t.lon_n
    WHEN t.lat_n BETWEEN 41 AND 51.2 AND t.lon_n BETWEEN -5.5 AND 9.7       THEN t.lon_n
    WHEN t.lon_n BETWEEN 41 AND 51.2 AND t.lat_n BETWEEN -5.5 AND 9.7       THEN t.lat_n  -- inversées
    ELSE NULL END,
  CASE
    WHEN t.outre_mer = 1                                                    THEN 'ok'
    WHEN t.lat_n BETWEEN 41 AND 51.2 AND t.lon_n BETWEEN -5.5 AND 9.7       THEN 'ok'
    WHEN t.lon_n BETWEEN 41 AND 51.2 AND t.lat_n BETWEEN -5.5 AND 9.7       THEN 'inversees corrigees'
    ELSE 'invalides' END
FROM (
  SELECT b.*,
         CAST(REPLACE(TRIM(b.lat),    ',', '.') AS DECIMAL(14,10)) AS lat_n,
         CAST(REPLACE(TRIM(b.`long`), ',', '.') AS DECIMAL(14,10)) AS lon_n,
         CASE WHEN TRIM(b.dep) REGEXP '^9[78]' THEN 1 ELSE 0 END    AS outre_mer
  FROM brut_caract b
) AS t;

-- Contrôle partie 1
SELECT annee, COUNT(*) AS nb_accidents FROM accident GROUP BY annee ORDER BY annee;
-- attendu : 58840 / 47744 / 56518 / 55302 / 54822 / 54402 / 55093
SELECT qualite_coord, COUNT(*) AS nb FROM accident GROUP BY qualite_coord;
-- attendu : ok = 382716, inversees corrigees = 4, invalides = 1
SELECT COUNT(*) AS departements_a_1_chiffre FROM accident WHERE departement REGEXP '^[0-9]$';
-- attendu : 0


-- ------------------------------------------------------------
-- PARTIE 2 : table LIEU (depuis brut_lieux)
-- ------------------------------------------------------------
-- Depuis 2023, certains accidents ont plusieurs lignes de lieux
-- (souvent un croisement de deux routes). On garde la PREMIÈRE
-- ligne du fichier (plus petit ligne_id), considérée comme le
-- lieu principal, et on note combien de lignes existaient.
CREATE TABLE lieu (
  Num_Acc             BIGINT UNSIGNED PRIMARY KEY,
  categorie_route     TINYINT,       -- catr
  voie                VARCHAR(60),   -- voie (numéro ou nom de la route)
  regime_circulation  TINYINT,       -- circ
  nb_voies            TINYINT,       -- nbv
  voie_reservee       TINYINT,       -- vosp
  profil_route        TINYINT,       -- prof
  trace_plan          TINYINT,       -- plan
  etat_surface        TINYINT,       -- surf
  infrastructure      TINYINT,       -- infra
  situation           TINYINT,       -- situ
  vitesse_max         SMALLINT,      -- vma (km/h)
  nb_lignes_source    TINYINT,       -- nombre de lignes de lieux dans le fichier d'origine
  FOREIGN KEY (Num_Acc) REFERENCES accident(Num_Acc)
);

INSERT INTO lieu
SELECT
  CAST(l.Num_Acc AS UNSIGNED),
  IF(TRIM(l.catr) REGEXP '^[0-9]+$', TRIM(l.catr), NULL),
  NULLIF(NULLIF(TRIM(l.voie),  ''), 'N/A'),
  IF(TRIM(l.circ) REGEXP '^[0-9]+$', TRIM(l.circ), NULL),
  -- nbv : on ne garde que les nombres > 0 (exclut -1, 0 et "#VALEURMULTI")
  CASE WHEN TRIM(l.nbv) REGEXP '^[0-9]+$' AND CAST(TRIM(l.nbv) AS UNSIGNED) > 0
       THEN CAST(TRIM(l.nbv) AS UNSIGNED) END,
  IF(TRIM(l.vosp) REGEXP '^[0-9]+$', TRIM(l.vosp), NULL),
  IF(TRIM(l.prof) REGEXP '^[0-9]+$', TRIM(l.prof), NULL),
  IF(TRIM(l.plan) REGEXP '^[0-9]+$', TRIM(l.plan), NULL),
  IF(TRIM(l.surf) REGEXP '^[0-9]+$', TRIM(l.surf), NULL),
  IF(TRIM(l.infra) REGEXP '^[0-9]+$', TRIM(l.infra), NULL),
  IF(TRIM(l.situ) REGEXP '^[0-9]+$', TRIM(l.situ), NULL),
  -- vma : valeurs incohérentes (< 5 ou > 130 km/h, ex. 500, 900) → NULL
  CASE WHEN TRIM(l.vma) REGEXP '^[0-9]+$'
            AND CAST(TRIM(l.vma) AS UNSIGNED) BETWEEN 5 AND 130
       THEN CAST(TRIM(l.vma) AS UNSIGNED) END,
  f.nb
FROM brut_lieux l
JOIN (
  SELECT Num_Acc, MIN(ligne_id) AS premiere_ligne, COUNT(*) AS nb
  FROM brut_lieux
  GROUP BY Num_Acc
) AS f ON f.premiere_ligne = l.ligne_id;

-- Contrôle partie 2
SELECT COUNT(*) AS nb_lieux FROM lieu;
-- attendu : 382721 (= un lieu par accident)
SELECT nb_lignes_source, COUNT(*) AS nb FROM lieu GROUP BY nb_lignes_source ORDER BY nb_lignes_source;
-- attendu : 1 → 335375 · 2 → 46834 · 3 → 466 · 4 → 43 · 5 → 3
SELECT COUNT(*) AS vitesses_ecartees
FROM brut_lieux
WHERE TRIM(vma) REGEXP '^[0-9]+$' AND CAST(TRIM(vma) AS UNSIGNED) NOT BETWEEN 5 AND 130;
-- attendu : 272


-- ------------------------------------------------------------
-- PARTIE 3 : table VEHICULE (depuis brut_vehicules)
-- ------------------------------------------------------------
CREATE TABLE vehicule (
  id_vehicule         BIGINT UNSIGNED PRIMARY KEY,
  Num_Acc             BIGINT UNSIGNED NOT NULL,
  num_veh             VARCHAR(5),    -- lettre du véhicule dans l'accident (A01, B01…)
  sens_circulation    TINYINT,       -- senc
  categorie_vehicule  TINYINT,       -- catv (vélo, voiture, trottinette…)
  obstacle_fixe       TINYINT,       -- obs
  obstacle_mobile     TINYINT,       -- obsm
  point_choc          TINYINT,       -- choc
  manoeuvre           TINYINT,       -- manv
  motorisation        TINYINT,       -- motor
  nb_occupants_tc     SMALLINT,      -- occutc (transports en commun)
  FOREIGN KEY (Num_Acc) REFERENCES accident(Num_Acc)
);

INSERT INTO vehicule
SELECT
  -- "155 975 242" (espaces insécables) → 155975242
  CAST(REGEXP_REPLACE(v.id_vehicule, '[^0-9]', '') AS UNSIGNED),
  CAST(v.Num_Acc AS UNSIGNED),
  TRIM(v.num_veh),
  IF(TRIM(v.senc) REGEXP '^[0-9]+$', TRIM(v.senc), NULL),
  IF(TRIM(v.catv) REGEXP '^[0-9]+$', TRIM(v.catv), NULL),
  IF(TRIM(v.obs) REGEXP '^[0-9]+$', TRIM(v.obs), NULL),
  IF(TRIM(v.obsm) REGEXP '^[0-9]+$', TRIM(v.obsm), NULL),
  IF(TRIM(v.choc) REGEXP '^[0-9]+$', TRIM(v.choc), NULL),
  IF(TRIM(v.manv) REGEXP '^[0-9]+$', TRIM(v.manv), NULL),
  IF(TRIM(v.motor) REGEXP '^[0-9]+$', TRIM(v.motor), NULL),
  IF(TRIM(v.occutc) REGEXP '^[0-9]+$', TRIM(v.occutc), NULL)
FROM brut_vehicules v;

-- Contrôle partie 3
SELECT LEFT(Num_Acc, 4) AS annee, COUNT(*) AS nb_vehicules
FROM vehicule GROUP BY annee ORDER BY annee;
-- attendu : 100710 / 81066 / 97315 / 94493 / 93585 / 92678 / 93865


-- ------------------------------------------------------------
-- PARTIE 4 : table USAGER (depuis brut_usagers)
-- ------------------------------------------------------------
-- id_usager n'existe dans les fichiers qu'à partir de 2021 :
-- on crée une clé technique (id_usager_cle) pour toutes les années
-- et on garde l'identifiant d'origine à titre d'information.
CREATE TABLE usager (
  id_usager_cle       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usager_source    BIGINT UNSIGNED NULL,  -- vide pour 2019-2020
  Num_Acc             BIGINT UNSIGNED NOT NULL,
  id_vehicule         BIGINT UNSIGNED NOT NULL,
  num_veh             VARCHAR(5),
  place               TINYINT,
  categorie_usager    TINYINT,       -- catu : 1 conducteur, 2 passager, 3 piéton
  gravite             TINYINT,       -- grav : 1 indemne, 2 tué, 3 blessé hospitalisé, 4 blessé léger
  sexe                TINYINT,
  annee_naissance     SMALLINT,
  age                 TINYINT,       -- calculé : année de l'accident - année de naissance
  motif_trajet        TINYINT,       -- trajet
  equipement_secu1    TINYINT,
  equipement_secu2    TINYINT,
  equipement_secu3    TINYINT,
  localisation_pieton TINYINT,       -- locp
  action_pieton       VARCHAR(2),    -- actp (contient aussi les lettres A et B)
  pieton_seul         TINYINT,       -- etatp
  FOREIGN KEY (Num_Acc)     REFERENCES accident(Num_Acc),
  FOREIGN KEY (id_vehicule) REFERENCES vehicule(id_vehicule)
);

INSERT INTO usager (
  id_usager_source, Num_Acc, id_vehicule, num_veh, place, categorie_usager,
  gravite, sexe, annee_naissance, age, motif_trajet,
  equipement_secu1, equipement_secu2, equipement_secu3,
  localisation_pieton, action_pieton, pieton_seul
)
SELECT
  CAST(NULLIF(REGEXP_REPLACE(IFNULL(u.id_usager, ''), '[^0-9]', ''), '') AS UNSIGNED),
  CAST(u.Num_Acc AS UNSIGNED),
  CAST(REGEXP_REPLACE(u.id_vehicule, '[^0-9]', '') AS UNSIGNED),
  TRIM(u.num_veh),
  IF(TRIM(u.place) REGEXP '^[0-9]+$', TRIM(u.place), NULL),
  IF(TRIM(u.catu) REGEXP '^[0-9]+$', TRIM(u.catu), NULL),
  IF(TRIM(u.grav) REGEXP '^[0-9]+$', TRIM(u.grav), NULL),
  IF(TRIM(u.sexe) REGEXP '^[0-9]+$', TRIM(u.sexe), NULL),
  u.an_nais_ok,
  CAST(LEFT(u.Num_Acc, 4) AS UNSIGNED) - u.an_nais_ok,
  IF(TRIM(u.trajet) REGEXP '^[0-9]+$', TRIM(u.trajet), NULL),
  IF(TRIM(u.secu1) REGEXP '^[0-9]+$', TRIM(u.secu1), NULL),
  IF(TRIM(u.secu2) REGEXP '^[0-9]+$', TRIM(u.secu2), NULL),
  IF(TRIM(u.secu3) REGEXP '^[0-9]+$', TRIM(u.secu3), NULL),
  IF(TRIM(u.locp) REGEXP '^[0-9]+$', TRIM(u.locp), NULL),
  IF(TRIM(u.actp) REGEXP '^[0-9AB]$', TRIM(u.actp), NULL),
  IF(TRIM(u.etatp) REGEXP '^[0-9]+$', TRIM(u.etatp), NULL)
FROM (
  SELECT b.*,
         -- année de naissance : on écarte les valeurs absentes et
         -- incohérentes (avant 1910, ou après l'année de l'accident)
         CASE WHEN TRIM(b.an_nais) REGEXP '^[0-9]{4}$'
                   AND CAST(TRIM(b.an_nais) AS UNSIGNED) BETWEEN 1910 AND CAST(LEFT(b.Num_Acc, 4) AS UNSIGNED)
              THEN CAST(TRIM(b.an_nais) AS UNSIGNED) END AS an_nais_ok
  FROM brut_usagers b
) AS u
ORDER BY u.ligne_id;

-- Contrôle partie 4
SELECT LEFT(Num_Acc, 4) AS annee,
       COUNT(*)                  AS nb_usagers,
       SUM(gravite = 2)          AS nb_tues,
       SUM(categorie_usager = 3) AS nb_pietons
FROM usager GROUP BY annee ORDER BY annee;
-- attendu (usagers) : 132977 / 105295 / 129248 / 126662 / 125789 / 125187 / 126376
-- attendu (tués)    :   3498 /   2780 /   3219 /   3550 /   3398 /   3432 /   3515
SELECT MIN(age) AS age_min, MAX(age) AS age_max, SUM(age IS NULL) AS age_inconnu FROM usager;
-- attendu : 0 / 110 / 13776
