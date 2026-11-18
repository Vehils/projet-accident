-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 6 : compte MySQL en lecture seule pour Tableau et Python
-- ============================================================
-- Principe du moindre privilège : Tableau et les notebooks Python
-- lisent les données mais ne peuvent rien modifier.
-- Le compte root reste réservé à l'administration (Navicat).
--
-- Le mot de passe est masqué : remplacer '********' par le vôtre.
-- ============================================================

CREATE USER IF NOT EXISTS 'tableau_user'@'%' IDENTIFIED BY '********';
GRANT SELECT ON accidents.* TO 'tableau_user'@'%';

-- vérification : on doit voir GRANT SELECT ON `accidents`.*
SHOW GRANTS FOR 'tableau_user'@'%';
