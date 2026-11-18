-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 6 : vues d'analyse pour Tableau
-- ============================================================
-- Une VUE est une requête enregistrée dans MySQL qui se comporte
-- comme une table, mais ne stocke aucune donnée : elle lit les
-- tables à chaque utilisation. Rien n'est supprimé ni modifié.
--
-- 3 vues, chacune à SON niveau de détail (pas de doublons) :
--   v_accident : 1 ligne par accident  (accident + lieu + libellés + bilan humain)
--   v_vehicule : 1 ligne par véhicule  (vehicule + libellé + famille)
--   v_usager   : 1 ligne par usager    (usager + libellés + type d'usager)
--
-- Dans Tableau :  v_accident ── v_vehicule ── v_usager
--                   (Num_Acc)      (id_vehicule)
--
-- Chaque variable codée est gardée en double :
--   xxx_code (le code d'origine) + xxx (le libellé lisible).
-- ============================================================

USE accidents;

-- ------------------------------------------------------------
-- VUE 1 : v_accident  (1 ligne par accident)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_accident AS
SELECT
  a.Num_Acc,
  a.date_accident,
  a.annee,
  a.mois,
  -- jour de la semaine en français (WEEKDAY : 0 = lundi … 6 = dimanche)
  WEEKDAY(a.date_accident) + 1                     AS jour_semaine_num,
  ELT(WEEKDAY(a.date_accident) + 1,
      'Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche') AS jour_semaine,
  a.heure,
  a.heure_num,
  a.departement,
  a.commune_insee,
  a.adresse,
  a.latitude,
  a.longitude,
  a.qualite_coord,
  -- circonstances (code + libellé)
  a.luminosite        AS luminosite_code,      rl.libelle  AS luminosite,
  a.agglomeration     AS agglomeration_code,   rag.libelle AS agglomeration,
  a.intersection      AS intersection_code,    ri.libelle  AS intersection,
  a.conditions_atmo   AS conditions_atmo_code, ra.libelle  AS conditions_atmo,
  a.type_collision    AS type_collision_code,  rc.libelle  AS type_collision,
  -- lieu (1 lieu par accident depuis l'étape 4)
  l.categorie_route   AS categorie_route_code, rr.libelle  AS categorie_route,
  l.etat_surface      AS etat_surface_code,    rs.libelle  AS etat_surface,
  l.voie,
  l.regime_circulation,
  l.nb_voies,
  l.voie_reservee,
  l.profil_route,
  l.trace_plan,
  l.infrastructure,
  l.situation,
  l.vitesse_max,
  -- bilan humain de l'accident (calculé à partir des usagers)
  COALESCE(b.nb_usagers, 0)        AS nb_usagers,
  COALESCE(b.nb_tues, 0)           AS nb_tues,
  COALESCE(b.nb_hospitalises, 0)   AS nb_hospitalises,
  COALESCE(b.nb_blesses_legers, 0) AS nb_blesses_legers,
  CASE
    WHEN b.nb_tues > 0         THEN 'Mortel'
    WHEN b.nb_hospitalises > 0 THEN 'Grave (hospitalisation)'
    ELSE 'Léger'
  END                              AS gravite_accident
FROM accident a
LEFT JOIN lieu l                 ON l.Num_Acc  = a.Num_Acc
LEFT JOIN ref_luminosite rl      ON rl.code  = a.luminosite
LEFT JOIN ref_agglomeration rag  ON rag.code = a.agglomeration
LEFT JOIN ref_intersection ri    ON ri.code  = a.intersection
LEFT JOIN ref_conditions_atmo ra ON ra.code  = a.conditions_atmo
LEFT JOIN ref_type_collision rc  ON rc.code  = a.type_collision
LEFT JOIN ref_categorie_route rr ON rr.code  = l.categorie_route
LEFT JOIN ref_etat_surface rs    ON rs.code  = l.etat_surface
LEFT JOIN (
  SELECT Num_Acc,
         COUNT(*)          AS nb_usagers,
         SUM(gravite = 2)  AS nb_tues,
         SUM(gravite = 3)  AS nb_hospitalises,
         SUM(gravite = 4)  AS nb_blesses_legers
  FROM usager
  GROUP BY Num_Acc
) AS b ON b.Num_Acc = a.Num_Acc;


-- ------------------------------------------------------------
-- VUE 2 : v_vehicule  (1 ligne par véhicule)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_vehicule AS
SELECT
  v.id_vehicule,
  v.Num_Acc,
  v.num_veh,
  v.categorie_vehicule AS categorie_vehicule_code,
  rv.libelle           AS categorie_vehicule,
  rv.famille           AS famille_vehicule,
  v.sens_circulation,
  v.obstacle_fixe,
  v.obstacle_mobile,
  v.point_choc,
  v.manoeuvre,
  v.motorisation,
  v.nb_occupants_tc
FROM vehicule v
LEFT JOIN ref_categorie_vehicule rv ON rv.code = v.categorie_vehicule;


-- ------------------------------------------------------------
-- VUE 3 : v_usager  (1 ligne par usager)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_usager AS
SELECT
  u.id_usager_cle,
  u.id_usager_source,
  u.Num_Acc,
  u.id_vehicule,
  u.num_veh,
  u.categorie_usager AS categorie_usager_code, rcu.libelle AS categorie_usager,
  -- type d'usager : piéton, ou sinon la famille du véhicule occupé
  CASE WHEN u.categorie_usager = 3 THEN 'Piéton'
       ELSE rv.famille END                                AS type_usager,
  u.gravite          AS gravite_code,          rg.libelle  AS gravite,
  rg.ordre_tri       AS gravite_ordre,
  -- indicateurs 0/1, pratiques pour additionner dans Tableau
  (u.gravite = 2)                                         AS est_tue,
  (u.gravite = 3)                                         AS est_hospitalise,
  (u.gravite IN (2, 3))                                   AS est_victime_grave,
  u.sexe             AS sexe_code,             rsx.libelle AS sexe,
  u.annee_naissance,
  u.age,
  CASE
    WHEN u.age IS NULL THEN NULL
    WHEN u.age < 15    THEN '0-14 ans'
    WHEN u.age < 18    THEN '15-17 ans'
    WHEN u.age < 25    THEN '18-24 ans'
    WHEN u.age < 35    THEN '25-34 ans'
    WHEN u.age < 45    THEN '35-44 ans'
    WHEN u.age < 55    THEN '45-54 ans'
    WHEN u.age < 65    THEN '55-64 ans'
    WHEN u.age < 75    THEN '65-74 ans'
    ELSE '75 ans et plus'
  END                                                     AS tranche_age,
  u.motif_trajet     AS motif_trajet_code,     rt.libelle  AS motif_trajet,
  u.place,
  u.equipement_secu1,
  u.equipement_secu2,
  u.equipement_secu3,
  u.localisation_pieton,
  u.action_pieton,
  u.pieton_seul
FROM usager u
LEFT JOIN vehicule v                ON v.id_vehicule = u.id_vehicule
LEFT JOIN ref_categorie_vehicule rv ON rv.code  = v.categorie_vehicule
LEFT JOIN ref_categorie_usager rcu  ON rcu.code = u.categorie_usager
LEFT JOIN ref_gravite rg            ON rg.code  = u.gravite
LEFT JOIN ref_sexe rsx              ON rsx.code = u.sexe
LEFT JOIN ref_motif_trajet rt       ON rt.code  = u.motif_trajet;


-- ------------------------------------------------------------
-- CONTRÔLES : les vues ont-elles le bon nombre de lignes ?
-- ------------------------------------------------------------
SELECT 'v_accident' AS vue, COUNT(*) AS nb FROM v_accident
UNION ALL SELECT 'v_vehicule', COUNT(*) FROM v_vehicule
UNION ALL SELECT 'v_usager',   COUNT(*) FROM v_usager;
-- Résultat obtenu le 13/11/2026 : 382721 / 653712 / 871534
-- (= exactement les tables d'origine : aucune ligne perdue ni dupliquée)

-- Exemple d'analyse : personnes tuées par type d'usager, 2019-2025
SELECT type_usager, SUM(est_tue) AS nb_tues
FROM v_usager
GROUP BY type_usager
ORDER BY nb_tues DESC;

-- Exemple d'analyse : accidents selon leur gravité, par année
SELECT annee, gravite_accident, COUNT(*) AS nb_accidents
FROM v_accident
GROUP BY annee, gravite_accident
ORDER BY annee, gravite_accident;
