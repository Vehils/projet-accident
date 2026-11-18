"""
Projet dataviz : accidents de la route 2019-2025
Audit de qualité des fichiers CSV sources (ONISR / BAAC, data.gouv.fr)

Objectif : détecter de façon systématique, AVANT l'import dans MySQL,
les anomalies de chaque fichier :
  - nombre de lignes et de colonnes, noms de colonnes inattendus
  - doublons sur la clé
  - cellules vides et valeurs "-1" (= non renseigné)
  - coordonnées GPS hors de la France métropolitaine (fichiers caract)
  - accidents avec plusieurs lignes de lieux (fichiers lieux)
  - espaces insécables dans les identifiants (vehicules, usagers)

Utilisation (dans un terminal, depuis le dossier du projet) :
    pip install pandas
    python scripts/audit_csv.py "C:/chemin/vers/le/dossier/des/csv"

Résultat :
  - un résumé affiché à l'écran
  - un fichier audit_qualite.csv (une ligne par fichier) dans le dossier des CSV
"""

import sys
import re
from pathlib import Path

import pandas as pd

# Colonnes attendues pour chaque type de fichier (format 2019+)
COLONNES_ATTENDUES = {
    "caract": ["Num_Acc", "jour", "mois", "an", "hrmn", "lum", "dep", "com",
               "agg", "int", "atm", "col", "adr", "lat", "long"],
    "lieux": ["Num_Acc", "catr", "voie", "v1", "v2", "circ", "nbv", "vosp", "prof",
              "pr", "pr1", "plan", "lartpc", "larrout", "surf", "infra", "situ", "vma"],
    "vehicules": ["Num_Acc", "id_vehicule", "num_veh", "senc", "catv", "obs",
                  "obsm", "choc", "manv", "motor", "occutc"],
    "usagers": ["Num_Acc", "id_usager", "id_vehicule", "num_veh", "place", "catu",
                "grav", "sexe", "an_nais", "trajet", "secu1", "secu2", "secu3",
                "locp", "actp", "etatp"],
}

# Rectangle approximatif de la France métropolitaine (Corse comprise)
LAT_MIN, LAT_MAX = 41.0, 51.2
LON_MIN, LON_MAX = -5.5, 9.7


def type_de_fichier(nom):
    """Déduit le type (caract, lieux, vehicules, usagers) du nom du fichier."""
    nom = nom.lower()
    if "caract" in nom or "carcteristiques" in nom:
        return "caract"
    for t in ("lieux", "vehicules", "usagers"):
        if t in nom:
            return t
    return None


def annee_du_fichier(nom):
    trouve = re.search(r"(20\d\d)", nom)
    return int(trouve.group(1)) if trouve else None


def auditer(chemin):
    """Retourne un dictionnaire de constats pour un fichier CSV."""
    t = type_de_fichier(chemin.name)
    df = pd.read_csv(chemin, sep=";", dtype=str, keep_default_na=False, encoding="utf-8")
    # nettoyage des noms de colonnes (ex. retour à la ligne dans "id_vehicule" en 2025)
    colonnes_brutes = list(df.columns)
    df.columns = [c.strip() for c in df.columns]

    r = {
        "fichier": chemin.name,
        "type": t,
        "annee": annee_du_fichier(chemin.name),
        "nb_lignes": len(df),
        "nb_colonnes": df.shape[1],
    }

    # 1. Noms de colonnes
    attendues = COLONNES_ATTENDUES[t]
    r["colonnes_manquantes"] = ", ".join(c for c in attendues if c not in df.columns)
    r["colonnes_inattendues"] = ", ".join(c for c in df.columns if c not in attendues)
    r["entete_avec_saut_ligne"] = any("\n" in c for c in colonnes_brutes)

    # Clé de l'accident (en 2022 le fichier caract l'appelle "Accident_Id")
    cle = "Num_Acc" if "Num_Acc" in df.columns else df.columns[0]
    r["nom_cle_accident"] = cle
    r["cles_mal_formees"] = int((~df[cle].str.match(r"^\d{12}$")).sum())

    # 2. Valeurs vides et "-1" (sur toutes les colonnes)
    valeurs = df.apply(lambda s: s.str.strip())
    r["cellules_vides"] = int((valeurs == "").sum().sum())
    r["valeurs_moins_1"] = int((valeurs == "-1").sum().sum())

    # 3. Contrôles propres à chaque type
    if t == "caract":
        r["doublons_cle"] = int(df[cle].duplicated().sum())
        lat = pd.to_numeric(df["lat"].str.strip().str.replace(",", "."), errors="coerce")
        lon = pd.to_numeric(df["long"].str.strip().str.replace(",", "."), errors="coerce")
        metropole = ~df["dep"].str.strip().str.match(r"^9[78]")
        hors = metropole & ~(lat.between(LAT_MIN, LAT_MAX) & lon.between(LON_MIN, LON_MAX))
        inversees = hors & lon.between(LAT_MIN, LAT_MAX) & lat.between(LON_MIN, LON_MAX)
        r["coord_non_numeriques"] = int((lat.isna() | lon.isna()).sum())
        r["coord_hors_metropole"] = int(hors.sum())
        r["coord_inversees_probables"] = int(inversees.sum())
        r["virgule_decimale"] = bool(df["lat"].str.contains(",").any())
        r["dep_a_1_chiffre"] = int(df["dep"].str.strip().str.match(r"^\d$").sum())

    if t == "lieux":
        nb = df[cle].value_counts()
        r["accidents_multi_lieux"] = int((nb > 1).sum())
        vma = pd.to_numeric(df["vma"].str.strip(), errors="coerce")
        r["vma_incoherente"] = int(((vma < 5) | (vma > 130)).fillna(False).sum() - (vma == -1).sum())
        r["nbv_non_numerique"] = int((~df["nbv"].str.strip().str.match(r"^-?\d+$")).sum())

    if t in ("vehicules", "usagers"):
        r["id_vehicule_espaces_insecables"] = int(df["id_vehicule"].str.contains("\u00a0").sum())
        if t == "vehicules":
            r["doublons_id_vehicule"] = int(df["id_vehicule"].duplicated().sum())

    if t == "usagers":
        an = pd.to_numeric(df["an_nais"].str.strip(), errors="coerce")
        r["an_nais_absente"] = int(an.isna().sum() + (an == -1).sum())
        r["an_nais_avant_1910"] = int(((an > 0) & (an < 1910)).sum())

    return r


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    dossier = Path(sys.argv[1])
    fichiers = sorted(f for f in dossier.glob("*.csv") if type_de_fichier(f.name))
    if not fichiers:
        print(f"Aucun fichier caract/lieux/vehicules/usagers trouvé dans {dossier}")
        sys.exit(1)

    resultats = []
    for f in fichiers:
        print(f"Audit de {f.name} ...")
        resultats.append(auditer(f))

    rapport = pd.DataFrame(resultats).sort_values(["type", "annee"])
    sortie = dossier / "audit_qualite.csv"
    rapport.to_csv(sortie, sep=";", index=False, encoding="utf-8-sig")

    # Résumé lisible
    pd.set_option("display.width", 200)
    pd.set_option("display.max_columns", 30)
    print("\n=== Nombre de lignes par fichier ===")
    print(rapport.pivot_table(index="annee", columns="type", values="nb_lignes", aggfunc="sum"))

    print("\n=== Anomalies détectées ===")
    colonnes_anomalies = [c for c in rapport.columns if c not in
                          ("fichier", "type", "annee", "nb_lignes", "nb_colonnes",
                           "nom_cle_accident", "virgule_decimale")]
    for _, ligne in rapport.iterrows():
        constats = []
        for c in colonnes_anomalies:
            v = ligne.get(c)
            if isinstance(v, str) and v:
                constats.append(f"{c} = {v}")
            elif isinstance(v, (bool,)) and v:
                constats.append(c)
            elif isinstance(v, (int, float)) and not pd.isna(v) and v > 0:
                constats.append(f"{c} = {int(v)}")
        if ligne["nom_cle_accident"] != "Num_Acc":
            constats.append(f"clé nommée '{ligne['nom_cle_accident']}'")
        print(f"- {ligne['fichier']} : " + ("; ".join(constats) if constats else "RAS"))

    print(f"\nRapport complet enregistré dans : {sortie}")


if __name__ == "__main__":
    main()
