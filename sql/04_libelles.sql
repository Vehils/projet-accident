-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 5 : tables de libellés (référentiels)
-- ============================================================
-- Les tables propres contiennent des CODES (gravite = 2,
-- categorie_vehicule = 33…). Ces petites tables "ref_" donnent
-- le LIBELLÉ de chaque code, tel que défini dans la documentation
-- officielle de l'ONISR (description-des-bases-de-donnees-annuelles.pdf).
--
-- Structure commune : code (clé primaire) + libelle.
-- Les codes "-1 = Non renseigné" ne sont pas repris : ils ont été
-- remplacés par NULL au nettoyage (étape 4).
--
-- Peut être exécuté en une seule fois (environ 30 secondes).
-- ============================================================

USE accidents;

-- ------------------------------------------------------------
-- PARTIE 0 : remise à zéro (utile seulement si on relance le script)
-- ------------------------------------------------------------
-- Au premier lancement, cette partie ne fait rien.
-- Pour RELANCER le script plus tard : il faudrait d'abord retirer les
-- clés étrangères ajoutées en partie 4 (ALTER TABLE … DROP FOREIGN KEY …),
-- sinon MySQL refuse de supprimer des tables encore référencées.
DROP TABLE IF EXISTS ref_gravite, ref_categorie_usager, ref_sexe, ref_motif_trajet,
                     ref_categorie_vehicule, ref_luminosite, ref_agglomeration,
                     ref_intersection, ref_conditions_atmo, ref_type_collision,
                     ref_categorie_route, ref_etat_surface;


-- ------------------------------------------------------------
-- PARTIE 1 : libellés des USAGERS
-- ------------------------------------------------------------
CREATE TABLE ref_gravite (
  code        TINYINT PRIMARY KEY,
  libelle     VARCHAR(40) NOT NULL,
  ordre_tri   TINYINT NOT NULL      -- pour trier du plus grave au moins grave
);
INSERT INTO ref_gravite VALUES
  (2, 'Tué',                1),
  (3, 'Blessé hospitalisé', 2),
  (4, 'Blessé léger',       3),
  (1, 'Indemne',            4);

CREATE TABLE ref_categorie_usager (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(40) NOT NULL
);
INSERT INTO ref_categorie_usager VALUES
  (1, 'Conducteur'),
  (2, 'Passager'),
  (3, 'Piéton');

CREATE TABLE ref_sexe (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(20) NOT NULL
);
INSERT INTO ref_sexe VALUES
  (1, 'Masculin'),
  (2, 'Féminin');

CREATE TABLE ref_motif_trajet (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(40) NOT NULL
);
INSERT INTO ref_motif_trajet VALUES
  (0, 'Non renseigné'),
  (1, 'Domicile – travail'),
  (2, 'Domicile – école'),
  (3, 'Courses – achats'),
  (4, 'Utilisation professionnelle'),
  (5, 'Promenade – loisirs'),
  (9, 'Autre');


-- ------------------------------------------------------------
-- PARTIE 2 : libellés des VÉHICULES
-- ------------------------------------------------------------
-- En plus du libellé officiel, une colonne "famille" regroupe les
-- 32 catégories en 8 familles lisibles pour les tableaux de bord.
-- (Les codes "inutilisés depuis 2006" ne sont pas repris : ils
--  n'apparaissent dans aucune donnée 2019-2025.)
CREATE TABLE ref_categorie_vehicule (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(80) NOT NULL,
  famille  VARCHAR(30) NOT NULL
);
INSERT INTO ref_categorie_vehicule VALUES
  ( 0, 'Indéterminable',                                   'Autre'),
  ( 1, 'Bicyclette',                                       'Vélo'),
  (80, 'Vélo à assistance électrique (VAE)',               'Vélo'),
  (50, 'EDP à moteur (trottinette électrique…)',           'Trottinette / EDP'),
  (60, 'EDP sans moteur (trottinette, roller…)',           'Trottinette / EDP'),
  ( 2, 'Cyclomoteur < 50 cm³',                             'Deux-roues motorisé'),
  (30, 'Scooter < 50 cm³',                                 'Deux-roues motorisé'),
  (31, 'Motocyclette > 50 cm³ et <= 125 cm³',              'Deux-roues motorisé'),
  (32, 'Scooter > 50 cm³ et <= 125 cm³',                   'Deux-roues motorisé'),
  (33, 'Motocyclette > 125 cm³',                           'Deux-roues motorisé'),
  (34, 'Scooter > 125 cm³',                                'Deux-roues motorisé'),
  (41, '3RM <= 50 cm³',                                    'Deux-roues motorisé'),
  (42, '3RM > 50 cm³ et <= 125 cm³',                       'Deux-roues motorisé'),
  (43, '3RM > 125 cm³',                                    'Deux-roues motorisé'),
  ( 3, 'Voiturette (quadricycle à moteur carrossé)',       'Voiture'),
  ( 7, 'Véhicule léger (VL) seul',                         'Voiture'),
  (10, 'Véhicule utilitaire (VU) 1,5 à 3,5 t',             'Utilitaire'),
  (13, 'Poids lourd 3,5 à 7,5 t',                          'Poids lourd'),
  (14, 'Poids lourd > 7,5 t',                              'Poids lourd'),
  (15, 'Poids lourd > 3,5 t + remorque',                   'Poids lourd'),
  (16, 'Tracteur routier seul',                            'Poids lourd'),
  (17, 'Tracteur routier + semi-remorque',                 'Poids lourd'),
  (37, 'Autobus',                                          'Transport en commun'),
  (38, 'Autocar',                                          'Transport en commun'),
  (40, 'Tramway',                                          'Transport en commun'),
  (39, 'Train',                                            'Autre'),
  (20, 'Engin spécial',                                    'Autre'),
  (21, 'Tracteur agricole',                                'Autre'),
  (35, 'Quad léger <= 50 cm³',                             'Autre'),
  (36, 'Quad lourd > 50 cm³',                              'Autre'),
  (99, 'Autre véhicule',                                   'Autre');


-- ------------------------------------------------------------
-- PARTIE 3 : libellés des ACCIDENTS et des LIEUX
-- ------------------------------------------------------------
CREATE TABLE ref_luminosite (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(60) NOT NULL
);
INSERT INTO ref_luminosite VALUES
  (1, 'Plein jour'),
  (2, 'Crépuscule ou aube'),
  (3, 'Nuit sans éclairage public'),
  (4, 'Nuit avec éclairage public non allumé'),
  (5, 'Nuit avec éclairage public allumé');

CREATE TABLE ref_agglomeration (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(30) NOT NULL
);
INSERT INTO ref_agglomeration VALUES
  (1, 'Hors agglomération'),
  (2, 'En agglomération');

CREATE TABLE ref_intersection (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(50) NOT NULL
);
INSERT INTO ref_intersection VALUES
  (1, 'Hors intersection'),
  (2, 'Intersection en X'),
  (3, 'Intersection en T'),
  (4, 'Intersection en Y'),
  (5, 'Intersection à plus de 4 branches'),
  (6, 'Giratoire'),
  (7, 'Place'),
  (8, 'Passage à niveau'),
  (9, 'Autre intersection');

CREATE TABLE ref_conditions_atmo (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(40) NOT NULL
);
INSERT INTO ref_conditions_atmo VALUES
  (1, 'Normale'),
  (2, 'Pluie légère'),
  (3, 'Pluie forte'),
  (4, 'Neige – grêle'),
  (5, 'Brouillard – fumée'),
  (6, 'Vent fort – tempête'),
  (7, 'Temps éblouissant'),
  (8, 'Temps couvert'),
  (9, 'Autre');

CREATE TABLE ref_type_collision (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(60) NOT NULL
);
INSERT INTO ref_type_collision VALUES
  (1, 'Deux véhicules – frontale'),
  (2, 'Deux véhicules – par l''arrière'),
  (3, 'Deux véhicules – par le côté'),
  (4, 'Trois véhicules et plus – en chaîne'),
  (5, 'Trois véhicules et plus – collisions multiples'),
  (6, 'Autre collision'),
  (7, 'Sans collision');

CREATE TABLE ref_categorie_route (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(60) NOT NULL
);
INSERT INTO ref_categorie_route VALUES
  (1, 'Autoroute'),
  (2, 'Route nationale'),
  (3, 'Route départementale'),
  (4, 'Voie communale'),
  (5, 'Hors réseau public'),
  (6, 'Parc de stationnement ouvert à la circulation'),
  (7, 'Route de métropole urbaine'),
  (9, 'Autre');

CREATE TABLE ref_etat_surface (
  code     TINYINT PRIMARY KEY,
  libelle  VARCHAR(30) NOT NULL
);
INSERT INTO ref_etat_surface VALUES
  (1, 'Normale'),
  (2, 'Mouillée'),
  (3, 'Flaques'),
  (4, 'Inondée'),
  (5, 'Enneigée'),
  (6, 'Boue'),
  (7, 'Verglacée'),
  (8, 'Corps gras – huile'),
  (9, 'Autre');


-- ------------------------------------------------------------
-- PARTIE 4 : contrôle puis clés étrangères
-- ------------------------------------------------------------
-- Contrôle : y a-t-il des codes dans les données qui n'ont PAS
-- de libellé ? Chaque colonne doit afficher 0.
SELECT
  (SELECT COUNT(*) FROM usager u   WHERE u.gravite IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_gravite r WHERE r.code = u.gravite))                  AS gravite,
  (SELECT COUNT(*) FROM usager u   WHERE u.categorie_usager IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_categorie_usager r WHERE r.code = u.categorie_usager)) AS cat_usager,
  (SELECT COUNT(*) FROM usager u   WHERE u.sexe IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_sexe r WHERE r.code = u.sexe))                        AS sexe,
  (SELECT COUNT(*) FROM usager u   WHERE u.motif_trajet IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_motif_trajet r WHERE r.code = u.motif_trajet))        AS trajet,
  (SELECT COUNT(*) FROM vehicule v WHERE v.categorie_vehicule IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_categorie_vehicule r WHERE r.code = v.categorie_vehicule)) AS cat_vehicule,
  (SELECT COUNT(*) FROM accident a WHERE a.luminosite IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_luminosite r WHERE r.code = a.luminosite))            AS luminosite,
  (SELECT COUNT(*) FROM accident a WHERE a.intersection IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_intersection r WHERE r.code = a.intersection))        AS intersection,
  (SELECT COUNT(*) FROM accident a WHERE a.conditions_atmo IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_conditions_atmo r WHERE r.code = a.conditions_atmo))  AS atmo,
  (SELECT COUNT(*) FROM accident a WHERE a.type_collision IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_type_collision r WHERE r.code = a.type_collision))    AS collision,
  (SELECT COUNT(*) FROM lieu l     WHERE l.categorie_route IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_categorie_route r WHERE r.code = l.categorie_route))  AS cat_route,
  (SELECT COUNT(*) FROM lieu l     WHERE l.etat_surface IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ref_etat_surface r WHERE r.code = l.etat_surface))        AS surface;
-- Résultat obtenu le 13/11/2026 : 0 partout.

-- Si tout est à 0, on déclare les relations dans MySQL :
-- chaque code devra désormais exister dans sa table de libellés.
ALTER TABLE usager
  ADD CONSTRAINT fk_usager_gravite   FOREIGN KEY (gravite)          REFERENCES ref_gravite(code),
  ADD CONSTRAINT fk_usager_categorie FOREIGN KEY (categorie_usager) REFERENCES ref_categorie_usager(code),
  ADD CONSTRAINT fk_usager_sexe      FOREIGN KEY (sexe)             REFERENCES ref_sexe(code),
  ADD CONSTRAINT fk_usager_trajet    FOREIGN KEY (motif_trajet)     REFERENCES ref_motif_trajet(code);

ALTER TABLE vehicule
  ADD CONSTRAINT fk_vehicule_categorie FOREIGN KEY (categorie_vehicule) REFERENCES ref_categorie_vehicule(code);

ALTER TABLE accident
  ADD CONSTRAINT fk_accident_luminosite    FOREIGN KEY (luminosite)      REFERENCES ref_luminosite(code),
  ADD CONSTRAINT fk_accident_agglomeration FOREIGN KEY (agglomeration)   REFERENCES ref_agglomeration(code),
  ADD CONSTRAINT fk_accident_intersection  FOREIGN KEY (intersection)    REFERENCES ref_intersection(code),
  ADD CONSTRAINT fk_accident_atmo          FOREIGN KEY (conditions_atmo) REFERENCES ref_conditions_atmo(code),
  ADD CONSTRAINT fk_accident_collision     FOREIGN KEY (type_collision)  REFERENCES ref_type_collision(code);

ALTER TABLE lieu
  ADD CONSTRAINT fk_lieu_categorie_route FOREIGN KEY (categorie_route) REFERENCES ref_categorie_route(code),
  ADD CONSTRAINT fk_lieu_surface         FOREIGN KEY (etat_surface)    REFERENCES ref_etat_surface(code);

-- Contrôle final : exemple de lecture avec libellés
SELECT g.libelle AS gravite, COUNT(*) AS nb_usagers
FROM usager u
JOIN ref_gravite g ON g.code = u.gravite
GROUP BY g.libelle, g.ordre_tri
ORDER BY g.ordre_tri;
-- Résultat obtenu le 13/11/2026 : Tué 23392 · Blessé hospitalisé 133984 ·
-- Blessé léger 346789 · Indemne 366950 (+ 419 usagers à gravité non renseignée)
