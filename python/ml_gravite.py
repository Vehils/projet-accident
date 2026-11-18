"""
Projet dataviz : accidents de la route 2019-2025
Machine learning : prédire si un accident sera MORTEL

Question : quels facteurs (heure, luminosité, météo, type de route,
vitesse maximale, véhicules impliqués…) sont le plus liés au fait
qu'un accident corporel soit mortel ?

Méthode : classification supervisée, avec 2 algorithmes comparés :
  - une régression logistique (modèle de référence, simple et lisible)
  - une forêt aléatoire (random forest), le modèle principal
  - Données lues directement dans MySQL (base « accidents », vues propres)
  - Apprentissage sur 2019-2023, test sur 2024-2025 (années jamais vues)
  - Classes déséquilibrées (≈ 5,8 % d'accidents mortels) :
    pondération des classes, et évaluation par AUC / rappel / précision
    plutôt que par l'exactitude seule
  - Aucune "triche" : le nombre de tués ou de blessés n'est jamais
    donné au modèle, puisque c'est ce qu'il doit deviner

Utilisation (terminal ou Anaconda Prompt) :
    pip install pandas scikit-learn sqlalchemy pymysql matplotlib
    python scripts/ml_gravite.py
Le script demande le mot de passe de l'utilisateur MySQL (non stocké).
Options : --user tableau_user --host localhost --port 3306

Résultats écrits dans le dossier ml_resultats/ :
    metriques.txt               performances du modèle
    importance_variables.csv    importance de chaque facteur
    importance_variables.png    le même classement en graphique
    predictions_2024_2025.csv   probabilité d'accident mortel, par accident
"""

import argparse
import getpass
from pathlib import Path

import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.compose import make_column_transformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.inspection import permutation_importance
from sklearn.metrics import (roc_auc_score, average_precision_score,
                             classification_report, confusion_matrix)

# ------------------------------------------------------------------
# 1. Requête SQL : une ligne par accident, avec ses circonstances
#    et la composition des véhicules / usagers impliqués
# ------------------------------------------------------------------
REQUETE = """
SELECT
  a.Num_Acc,
  a.annee,
  a.mois,
  a.heure_num,
  a.jour_semaine_num,
  a.luminosite_code,
  a.agglomeration_code,
  a.intersection_code,
  a.conditions_atmo_code,
  a.type_collision_code,
  a.categorie_route_code,
  a.etat_surface_code,
  a.vitesse_max,
  a.nb_voies,
  a.profil_route,
  a.trace_plan,
  CASE WHEN a.departement REGEXP '^9[78]' THEN 1 ELSE 0 END AS outre_mer,
  v.nb_vehicules,
  v.avec_velo,
  v.avec_trottinette,
  v.avec_deux_roues_motorise,
  v.avec_poids_lourd,
  v.avec_obstacle_fixe,
  u.nb_usagers,
  u.avec_pieton,
  u.avec_senior_75,
  u.avec_jeune_18_24,
  CASE WHEN a.gravite_accident = 'Mortel' THEN 1 ELSE 0 END AS mortel
FROM v_accident a
JOIN (
  SELECT Num_Acc,
         COUNT(*)                                          AS nb_vehicules,
         MAX(famille_vehicule = 'Vélo')                    AS avec_velo,
         MAX(famille_vehicule = 'Trottinette / EDP')       AS avec_trottinette,
         MAX(famille_vehicule = 'Deux-roues motorisé')     AS avec_deux_roues_motorise,
         MAX(famille_vehicule = 'Poids lourd')             AS avec_poids_lourd,
         MAX(obstacle_fixe BETWEEN 1 AND 17)               AS avec_obstacle_fixe
  FROM v_vehicule
  GROUP BY Num_Acc
) v ON v.Num_Acc = a.Num_Acc
JOIN (
  SELECT Num_Acc,
         COUNT(*)                         AS nb_usagers,
         MAX(categorie_usager_code = 3)   AS avec_pieton,
         MAX(age >= 75)                   AS avec_senior_75,
         MAX(age BETWEEN 18 AND 24)       AS avec_jeune_18_24
  FROM v_usager
  GROUP BY Num_Acc
) u ON u.Num_Acc = a.Num_Acc
"""

# Noms lisibles pour le graphique
LIBELLES = {
    "mois": "Mois", "heure_num": "Heure", "jour_semaine_num": "Jour de la semaine",
    "luminosite_code": "Luminosité", "agglomeration_code": "En / hors agglomération",
    "intersection_code": "Type d'intersection", "conditions_atmo_code": "Météo",
    "type_collision_code": "Type de collision", "categorie_route_code": "Catégorie de route",
    "etat_surface_code": "État de la chaussée", "vitesse_max": "Vitesse max autorisée",
    "nb_voies": "Nombre de voies", "profil_route": "Profil (pente)", "trace_plan": "Tracé (virage)",
    "outre_mer": "Outre-mer", "nb_vehicules": "Nombre de véhicules",
    "avec_velo": "Vélo impliqué", "avec_trottinette": "Trottinette impliquée",
    "avec_deux_roues_motorise": "Deux-roues motorisé impliqué",
    "avec_poids_lourd": "Poids lourd impliqué", "avec_obstacle_fixe": "Choc contre un obstacle fixe",
    "nb_usagers": "Nombre de personnes impliquées", "avec_pieton": "Piéton impliqué",
    "avec_senior_75": "Personne de 75 ans ou plus", "avec_jeune_18_24": "Personne de 18-24 ans",
}


def main():
    parser = argparse.ArgumentParser(description="Prédiction des accidents mortels")
    parser.add_argument("--user", default="tableau_user")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", default="3306")
    parser.add_argument("--base", default="accidents")
    args = parser.parse_args()

    mdp = getpass.getpass(f"Mot de passe MySQL de {args.user} : ")
    moteur = create_engine(
        f"mysql+pymysql://{args.user}:{mdp}@{args.host}:{args.port}/{args.base}?charset=utf8mb4")

    sortie = Path("ml_resultats")
    sortie.mkdir(exist_ok=True)

    # --------------------------------------------------------------
    # 2. Lecture des données
    # --------------------------------------------------------------
    print("Lecture des données dans MySQL (environ 30 secondes)…")
    df = pd.read_sql(REQUETE, moteur)
    nb, nb_m = f"{len(df):,}".replace(",", " "), f"{df['mortel'].sum():,}".replace(",", " ")
    print(f"{nb} accidents lus, dont {nb_m} mortels ({df['mortel'].mean():.1%}).")

    variables = [c for c in df.columns if c not in ("Num_Acc", "annee", "mortel")]
    # Les valeurs non renseignées (NULL) deviennent -1 : une catégorie « inconnu »
    X = df[variables].apply(pd.to_numeric, errors="coerce").fillna(-1)
    y = df["mortel"].astype(int)

    # --------------------------------------------------------------
    # 3. Découpage dans le temps : on apprend sur le passé,
    #    on teste sur des années que le modèle n'a jamais vues
    # --------------------------------------------------------------
    apprentissage = df["annee"] <= 2023
    X_app, y_app = X[apprentissage], y[apprentissage]
    X_test, y_test = X[~apprentissage], y[~apprentissage]
    print(f"Apprentissage 2019-2023 : {len(X_app)} accidents · Test 2024-2025 : {len(X_test)} accidents")

    # --------------------------------------------------------------
    # 4. Forêt aléatoire, avec pondération des classes
    # --------------------------------------------------------------
    print("Entraînement de la forêt aléatoire (1 à 3 minutes)…")
    modele = RandomForestClassifier(
        n_estimators=300,
        min_samples_leaf=20,
        class_weight="balanced_subsample",
        n_jobs=-1,
        random_state=42,
    )
    modele.fit(X_app, y_app)

    # Modèle de référence : régression logistique.
    # Les codes (luminosité, météo…) sont des catégories, pas des quantités :
    # on les transforme en colonnes 0/1 (one-hot) ; les nombres sont standardisés.
    print("Entraînement de la régression logistique (modèle de référence)…")
    categorielles = [c for c in variables if c.endswith("_code")
                     or c in ("mois", "heure_num", "jour_semaine_num", "profil_route", "trace_plan")]
    numeriques = [c for c in variables if c not in categorielles]
    logistique = make_pipeline(
        make_column_transformer(
            (OneHotEncoder(handle_unknown="ignore"), categorielles),
            (StandardScaler(), numeriques)),
        LogisticRegression(class_weight="balanced", max_iter=2000))
    logistique.fit(X_app, y_app)
    auc_logistique = roc_auc_score(y_test, logistique.predict_proba(X_test)[:, 1])

    # --------------------------------------------------------------
    # 5. Évaluation sur 2024-2025
    # --------------------------------------------------------------
    proba = modele.predict_proba(X_test)[:, 1]
    prediction = (proba >= 0.5).astype(int)
    auc = roc_auc_score(y_test, proba)
    ap = average_precision_score(y_test, proba)
    taux_base = y_test.mean()
    mc = confusion_matrix(y_test, prediction)

    texte = []
    texte.append("PRÉDICTION DES ACCIDENTS MORTELS – FORÊT ALÉATOIRE")
    texte.append("Apprentissage : 2019-2023 · Test : 2024-2025\n")
    texte.append(f"Part réelle d'accidents mortels dans le test : {taux_base:.1%}")
    texte.append("Comparaison des 2 algorithmes (AUC ROC sur 2024-2025, 0,5 = hasard, 1 = parfait) :")
    texte.append(f"  régression logistique (référence) : {auc_logistique:.3f}")
    texte.append(f"  forêt aléatoire (modèle retenu)   : {auc:.3f}\n")
    texte.append("Détail de la forêt aléatoire :")
    texte.append(f"Précision moyenne (AP) : {ap:.3f}  (à comparer à {taux_base:.3f} pour un tirage au hasard)\n")
    texte.append("Matrice de confusion (seuil 0,5) :")
    texte.append(f"  vrais non mortels prédits non mortels : {mc[0, 0]}")
    texte.append(f"  vrais non mortels prédits mortels     : {mc[0, 1]}")
    texte.append(f"  vrais mortels prédits non mortels     : {mc[1, 0]}")
    texte.append(f"  vrais mortels prédits mortels         : {mc[1, 1]}\n")
    texte.append(classification_report(y_test, prediction,
                                       target_names=["Non mortel", "Mortel"], digits=3))
    rapport = "\n".join(texte)
    print("\n" + rapport)
    (sortie / "metriques.txt").write_text(rapport, encoding="utf-8")

    # --------------------------------------------------------------
    # 6. Importance des variables (par permutation, sur le test) :
    #    de combien l'AUC baisse si on mélange une variable au hasard
    # --------------------------------------------------------------
    print("Calcul de l'importance des facteurs (1 à 2 minutes)…")
    echantillon = X_test.sample(n=min(30000, len(X_test)), random_state=42)
    imp = permutation_importance(modele, echantillon, y_test.loc[echantillon.index],
                                 scoring="roc_auc", n_repeats=5,
                                 random_state=42, n_jobs=-1)
    importance = (pd.DataFrame({"variable": variables,
                                "facteur": [LIBELLES.get(v, v) for v in variables],
                                "baisse_auc": imp.importances_mean})
                  .sort_values("baisse_auc", ascending=False))
    importance.to_csv(sortie / "importance_variables.csv", sep=";", index=False,
                      encoding="utf-8-sig", decimal=",")
    print(importance.head(10).to_string(index=False))

    top = importance.head(12).iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(top["facteur"], top["baisse_auc"], color="#B4501C")
    ax.set_xlabel("Baisse de l'AUC quand le facteur est brouillé (plus c'est long, plus il compte)")
    ax.set_title("Facteurs les plus liés aux accidents mortels (forêt aléatoire, test 2024-2025)")
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(sortie / "importance_variables.png", dpi=150)

    # --------------------------------------------------------------
    # 7. Probabilités prédites (réutilisables dans Tableau)
    # --------------------------------------------------------------
    pd.DataFrame({"Num_Acc": df.loc[~apprentissage, "Num_Acc"],
                  "proba_mortel": proba.round(4),
                  "mortel_reel": y_test}).to_csv(
        sortie / "predictions_2024_2025.csv", sep=";", index=False, decimal=",")

    print(f"\nTerminé. Résultats dans le dossier : {sortie.resolve()}")


if __name__ == "__main__":
    main()
