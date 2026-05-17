# 🌍 Analyse Géopolitique & Économique — USA · Israël · Iran
### Analyse temporelle, militaire, pétrolière et apprentissage automatique (1948–2024)

> **Tek-Up University** · Méthodes Statistiques & Étude de Données · 2024–2025  
> Encadrant : **Pr. Ahmed Dhouibi**

---

## 👥 Auteurs

| Nom | Rôle |
|-----|------|
| **Fatma Ayadi** | Analyse statistique, modélisation ML, rédaction |
| **Arij Khemiri** | Collecte de données, preprocessing, visualisation, rédaction |

---

## 📋 Description du projet

Ce projet analyse quantitativement les relations entre **tensions géopolitiques** et **indicateurs économiques** pour trois acteurs clés du Moyen-Orient — États-Unis, Israël et Iran — sur **76 ans de données** (1948–2024).

Le pipeline complet couvre :
- La **collecte et fusion** de deux sources de données hétérogènes
- Le **preprocessing** avancé avec imputation GM(1,1) (modèle gris) et winsorisation
- L'**analyse exploratoire** multi-dimensionnelle (12 modules)
- L'**apprentissage supervisé** (régression linéaire, Random Forest, arbre de décision)
- L'**apprentissage non supervisé** (ACP, K-means, CAH)
- Les **implications business et stratégiques** de l'analyse

---

## 🗂️ Structure du projet

```
📁 projet-geopolitique/
│
├── 📁 code/
│   ├── Data_collect.R        # Étape 1 — Collecte, fusion et EDA initiale
│   ├── preprocessing.R       # Étape 2 — Nettoyage, imputation GM(1,1), winsorisation
│   └── Analyse_varié.R       # Étape 3 — 12 modules d'analyse + ML
│
├── 📁 data/
│   ├── war_history_economics_1948_2026.csv      # Source 1 : conflits & militaire
│   ├── Middle_East_Economic_Data_1990_2024.csv  # Source 2 : économie & pétrole
│   ├── data.csv                                 # Dataset intermédiaire (après fusion)
│   └── data_clean.csv                           # Dataset final (après preprocessing)
│
├── 📁 outputs/               # Graphiques générés automatiquement (22 fichiers PNG)
│   ├── 01_analyse_temporelle.png
│   ├── 02_comparaison_pays.png
│   ├── 03_analyse_militaire.png
│   ├── ...
│   └── 22_cah_sur_acp.png
│
├── 📄 rapport.Rmd            # Rapport final (R Markdown — HTML)
├── 📄 rapport.html           # Rapport compilé (knit)
└── 📄 README.md              # Ce fichier
```

---

## 📊 Données

### Sources brutes

| Fichier | Description | Période | Source |
|---------|-------------|---------|--------|
| `war_history_economics_1948_2026.csv` | Conflits, dépenses militaires, personnel actif, indice de sévérité | 1948–2026 | Kaggle — Lodhra, A. (2024) |
| `Middle_East_Economic_Data_1990_2024_with_Oil.csv` | PIB, inflation, chômage, prix du Brent | 1990–2024 | Kaggle — Shanali, M. (2024) |

### Dataset final (`data_clean.csv`)

| Dimension | Valeur |
|-----------|--------|
| **Observations** | 231 lignes (3 pays × 77 années) |
| **Variables** | 12 colonnes |
| **Pays** | USA · Israël · Iran |
| **Période** | 1948 – 2024 |

### Variables clés

| Variable | Description | Unité |
|----------|-------------|-------|
| `country` | Pays | — |
| `year` | Année | — |
| `periode` | Période géopolitique encodée | Paix / Conflit modéré / Conflit intense |
| `GDP_Growth_Percent` | Croissance annuelle du PIB | % |
| `GDP_current_USD` | PIB courant | USD |
| `Inflation_Rate_Percent` | Taux d'inflation | % |
| `Unemployment_total_pct` | Taux de chômage | % |
| `Military_Expenditure_Billion_USD` | Dépenses militaires | Milliards USD |
| `Active_Personnel` | Personnel militaire actif | Soldats |
| `Conflict_Severity_Index` | Indice de sévérité du conflit | 0–5 |
| `Brent_Oil_Price_USD_per_barrel` | Prix du Brent | USD/baril |
| `Significant_Event` | Événement géopolitique majeur | Texte |

---

## ⚙️ Pipeline de traitement

### Étape 1 — Collecte (`Data_collect.R`)

- Chargement des deux sources CSV
- Filtrage sur les 3 pays cibles (USA, Israel, Iran)
- Fusion gauche (`left_join`) sur `country` + `year`
- Encodage de la variable `periode` à partir du `Conflict_Severity_Index`
- Analyse exploratoire initiale : corrélation Brent × sévérité, visualisations EDA
- Export intermédiaire → `data/data.csv`

### Étape 2 — Preprocessing (`preprocessing.R`)

- Sélection des 12 variables pertinentes
- **Imputation GM(1,1)** (Modèle Gris) pour 3 variables : `GDP_current_USD`, `Brent_Oil_Price_USD_per_barrel`, `Unemployment_total_pct`
  - Méthode : accumulation génératrice AGO + estimation OLS des paramètres *a* et *b*
  - Fallback automatique : médiane par pays si série trop courte (< 4 valeurs non-NA)
- Remplacement des NA résiduels par la **médiane globale**
- **Détection des outliers** par méthode IQR (Q1 − 1.5×IQR / Q3 + 1.5×IQR)
- **Winsorisation** : remplacement des valeurs extrêmes par les bornes IQR (pas de suppression)
- Export final → `data/data_clean.csv`

### Étape 3 — Analyse (`Analyse_varié.R`)

12 modules d'analyse produits automatiquement dans `outputs/` :

| Module | Contenu | Fichier généré |
|--------|---------|----------------|
| 1 | Analyse temporelle : PIB, conflit, inflation | `01_analyse_temporelle.png` |
| 2 | Comparaison pays + K-means (k=4) | `02_comparaison_pays.png` |
| 3 | Analyse militaire : dépenses, personnel | `03_analyse_militaire.png` |
| 4 | Pétrole, inflation & conflits | `04_petrole_inflation.png` |
| 5 | Analyse avant/après événements USA (±5 ans) | `05_avant_apres.png` |
| 6 | Matrice de corrélation Pearson | `06_correlation.png` |
| 7 | Profils par période de conflit | `07_profils_periodes.png` |
| 8 | Régression linéaire : Brent & inflation Iran | `08_regression.png` |
| 9 | Random Forest + Arbre de décision | `09_random_forest.png` |
| 10 | ACP (FactoMineR) : scree plot, cercle, biplot | `10_17_acp.png` |
| 11 | K-means (k=3) : coude, silhouette, profils | `18_choix_kmeans.png` · `19_clusters_kmeans.png` · `20_profils_clusters.png` |
| 12 | CAH (Ward) : dendrogramme + groupes sur ACP | `21_dendrogramme.png` · `22_cah_sur_acp.png` |

---

## 🚀 Lancer le projet

### Prérequis

- [R](https://cran.r-project.org/) ≥ 4.2.0
- [RStudio](https://posit.co/download/rstudio-desktop/) (recommandé)

### Packages R

Les packages sont installés automatiquement au lancement de `Analyse_varié.R`. Liste complète :

```r
c("tidyverse", "ggplot2", "scales", "patchwork",
  "ggcorrplot", "factoextra", "cluster", "FactoMineR",
  "randomForest", "caret", "rpart", "rpart.plot",
  "ggrepel", "viridis", "knitr", "kableExtra", "readr")
```

### Instructions pas à pas

**1. Cloner le dépôt**
```bash
git clone https://github.com/votre-utilisateur/nom-du-repo.git
cd nom-du-repo
```

**2. Placer les fichiers sources** dans le dossier `data/`

**3. Mettre à jour les chemins** dans chaque script (remplacer les chemins absolus) :

```r
# Data_collect.R — lignes 9-10
d_conflict <- read_csv("data/war_history_economics_1948_2026.csv")
d_eco      <- read_csv("data/Middle_East_Economic_Data_1990_2024_with_Oil.csv")

# preprocessing.R — ligne 6
df <- read.csv("data/data.csv")

# Analyse_varié.R — lignes 29-30
PATH_DATA   <- "data/data_clean.csv"
PATH_OUTPUT <- "outputs/"
```

**4. Exécuter les scripts dans l'ordre**
```r
source("code/Data_collect.R")    # → génère data/data.csv
source("code/preprocessing.R")   # → génère data/data_clean.csv
source("code/Analyse_varié.R")   # → génère les 22 PNG dans outputs/
```

**5. Compiler le rapport HTML**
```r
rmarkdown::render("rapport.Rmd")
```
Ou depuis RStudio : bouton **Knit → Knit to HTML**

---

## 📌 Résultats clés

- 📈 Le **prix du Brent** est 30 à 40 $/baril plus élevé en période de conflit intense
- 🎯 Le **Random Forest** classe les périodes géopolitiques avec une accuracy > 85%
- 🔍 **K-means (k=3) et CAH convergent** vers les mêmes 3 groupes sans connaissance a priori des périodes historiques
- 💸 Les **sanctions financières** (exclusion SWIFT, blocage des réserves) déstabilisent davantage l'Iran que les conflits militaires directs
- 📊 Le **Conflict_Severity_Index** est la variable la plus prédictive dans tous les modèles supervisés (Random Forest, régression, arbre)

---

## 📚 Références

| Source | Lien |
|--------|------|
| Banque Mondiale — World Development Indicators | https://databank.worldbank.org |
| SIPRI — Military Expenditure Database | https://www.sipri.org/databases/milex |
| U.S. EIA — Brent Spot Price | https://www.eia.gov |
| UCDP — Uppsala Conflict Data Program v23.1 | https://ucdp.uu.se |
| Kaggle — Lodhra, A. (2024) | https://www.kaggle.com/datasets/abdulmaliklodhra/usa-israel-iran-war-history-and-analysis |
| Kaggle — Shanali, M. (2024) | https://www.kaggle.com/datasets/meharshanali/middle-east-economy-and-oil-prices-19902024 |

---

## 📄 Licence

Projet académique — Tek-Up University · 2024–2025.  
Usage éducatif uniquement. Les données proviennent de sources publiques citées ci-dessus.

---

<div align="center">
  <sub>Fatma Ayadi & Arij Khemiri · Tek-Up University · Pr. Ahmed Dhouibi · 2025</sub>
</div>