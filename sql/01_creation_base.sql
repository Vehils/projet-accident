-- ============================================================
-- Projet dataviz : accidents de la route 2019-2025
-- ÉTAPE 1 : création de la base et des 4 tables brutes
-- ============================================================
-- Tables "brutes" : toutes les colonnes en texte (VARCHAR),
-- pour que l'import n'échoue jamais. Le typage et le nettoyage
-- se feront ensuite, en SQL, dans des tables propres.
--
-- ligne_id : numéro auto-incrémenté qui garde l'ordre des lignes
-- du fichier (indispensable pour garder la 1re ligne de lieux
-- par accident à l'étape de nettoyage).
--
-- `int` et `long` sont des mots réservés en MySQL :
-- il faut les écrire entre backticks.
-- ============================================================

CREATE DATABASE IF NOT EXISTS accidents
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE accidents;

CREATE TABLE brut_caract (
  ligne_id INT AUTO_INCREMENT PRIMARY KEY,
  Num_Acc  VARCHAR(12),
  jour     VARCHAR(2),
  mois     VARCHAR(2),
  an       VARCHAR(4),
  hrmn     VARCHAR(5),
  lum      VARCHAR(3),
  dep      VARCHAR(3),
  com      VARCHAR(5),
  agg      VARCHAR(3),
  `int`    VARCHAR(3),
  atm      VARCHAR(3),
  col      VARCHAR(3),
  adr      VARCHAR(255),
  lat      VARCHAR(20),
  `long`   VARCHAR(20)
);

CREATE TABLE brut_lieux (
  ligne_id INT AUTO_INCREMENT PRIMARY KEY,
  Num_Acc  VARCHAR(12),
  catr     VARCHAR(3),
  voie     VARCHAR(60),
  v1       VARCHAR(5),
  v2       VARCHAR(10),
  circ     VARCHAR(3),
  nbv      VARCHAR(15),
  vosp     VARCHAR(3),
  prof     VARCHAR(3),
  pr       VARCHAR(6),
  pr1      VARCHAR(6),
  plan     VARCHAR(3),
  lartpc   VARCHAR(20),
  larrout  VARCHAR(20),
  surf     VARCHAR(3),
  infra    VARCHAR(3),
  situ     VARCHAR(3),
  vma      VARCHAR(3)
);

CREATE TABLE brut_vehicules (
  ligne_id    INT AUTO_INCREMENT PRIMARY KEY,
  Num_Acc     VARCHAR(12),
  id_vehicule VARCHAR(15),
  num_veh     VARCHAR(5),
  senc        VARCHAR(3),
  catv        VARCHAR(3),
  obs         VARCHAR(3),
  obsm        VARCHAR(3),
  choc        VARCHAR(3),
  manv        VARCHAR(3),
  motor       VARCHAR(3),
  occutc      VARCHAR(3)
);

CREATE TABLE brut_usagers (
  ligne_id    INT AUTO_INCREMENT PRIMARY KEY,
  Num_Acc     VARCHAR(12),
  id_usager   VARCHAR(15),
  id_vehicule VARCHAR(15),
  num_veh     VARCHAR(5),
  place       VARCHAR(3),
  catu        VARCHAR(3),
  grav        VARCHAR(3),
  sexe        VARCHAR(3),
  an_nais     VARCHAR(4),
  trajet      VARCHAR(3),
  secu1       VARCHAR(3),
  secu2       VARCHAR(3),
  secu3       VARCHAR(3),
  locp        VARCHAR(3),
  actp        VARCHAR(3),
  etatp       VARCHAR(3)
);
