-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 2 : contrôles après l'import des CSV (Navicat)
-- ============================================================
-- L'import des 28 CSV se fait avec l'assistant d'import de Navicat
-- (réglages dans le README, section 5.1). Ce script vérifie ensuite
-- que tout est bien arrivé, retire les lignes vides de fin de
-- fichier et prépare les jointures (index).
-- ============================================================

USE accidents;

-- ------------------------------------------------------------
-- 1. Lignes vides de fin de fichier
--    (une ligne vide en fin de CSV crée une ligne sans Num_Acc)
-- ------------------------------------------------------------
SELECT COUNT(*) FROM brut_caract   WHERE Num_Acc IS NULL;  -- attendu : 7
SELECT COUNT(*) FROM brut_lieux    WHERE Num_Acc IS NULL;  -- attendu : 6
SELECT COUNT(*) FROM brut_vehicules WHERE Num_Acc IS NULL; -- attendu : 5
SELECT COUNT(*) FROM brut_usagers  WHERE Num_Acc IS NULL;  -- attendu : 6

DELETE FROM brut_caract    WHERE Num_Acc IS NULL;
DELETE FROM brut_lieux     WHERE Num_Acc IS NULL;
DELETE FROM brut_vehicules WHERE Num_Acc IS NULL;
DELETE FROM brut_usagers   WHERE Num_Acc IS NULL;

-- ------------------------------------------------------------
-- 2. Comptage des lignes par année
--    (à comparer au nombre de lignes de chaque CSV)
-- ------------------------------------------------------------
SELECT an, COUNT(*) AS nb_lignes
FROM brut_caract
GROUP BY an
ORDER BY an;
-- attendu : 58 840 / 47 744 / 56 518 / 55 302 / 54 822 / 54 402 / 55 093
-- total   : 382 721

-- l'année n'est que dans caract : on la retrouve par le début de Num_Acc
SELECT LEFT(Num_Acc, 4) AS annee, COUNT(*) AS nb_lignes
FROM brut_usagers
GROUP BY annee
ORDER BY annee;

-- ------------------------------------------------------------
-- 3. Index sur les clés de jointure
--    (sans index, les jointures sur des centaines de milliers
--     de lignes prennent plusieurs minutes)
-- ------------------------------------------------------------
CREATE INDEX idx_caract_acc  ON brut_caract (Num_Acc);
CREATE INDEX idx_lieux_acc   ON brut_lieux (Num_Acc);
CREATE INDEX idx_veh_acc     ON brut_vehicules (Num_Acc);
CREATE INDEX idx_veh_id      ON brut_vehicules (id_vehicule);
CREATE INDEX idx_usagers_acc ON brut_usagers (Num_Acc);
CREATE INDEX idx_usagers_veh ON brut_usagers (id_vehicule);

-- ------------------------------------------------------------
-- 4. Lignes orphelines
--    (un lieu, un véhicule ou un usager sans accident correspondant)
-- ------------------------------------------------------------
SELECT COUNT(*) AS lieux_orphelins
FROM brut_lieux l
LEFT JOIN brut_caract c ON c.Num_Acc = l.Num_Acc
WHERE c.Num_Acc IS NULL;              -- attendu : 0

SELECT COUNT(*) AS vehicules_orphelins
FROM brut_vehicules v
LEFT JOIN brut_caract c ON c.Num_Acc = v.Num_Acc
WHERE c.Num_Acc IS NULL;              -- attendu : 0

SELECT COUNT(*) AS usagers_orphelins
FROM brut_usagers u
LEFT JOIN brut_caract c ON c.Num_Acc = u.Num_Acc
WHERE c.Num_Acc IS NULL;              -- attendu : 0
