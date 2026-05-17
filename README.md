# 🌍 Analyse Géopolitique & Économique — USA · Israël · Iran

> Analyse temporelle, militaire, pétrolière et apprentissage automatique (1948–2024)  
> **Tek-Up University** · Méthodes Statistiques & Étude de Données · 2024–2025  
> Encadrant : **Pr. Ahmed Dhouibi**

---

## 👥 Auteurs

| Nom | Rôle |
|-----|------|
| **Fatma Ayadi** | Analyse, modélisation ML, rédaction |
| **Arij Khemiri** | Analyse, visualisation, rédaction |

---

## 📋 Description du projet

Ce rapport analyse quantitativement les relations entre **tensions géopolitiques** et **indicateurs économiques** pour trois acteurs clés du Moyen-Orient — États-Unis, Israël et Iran — sur une période de 76 ans (1948–2024).

Il mobilise un pipeline complet allant de l'exploration descriptive jusqu'à l'apprentissage automatique supervisé et non supervisé, avec une section dédiée aux **implications business et stratégiques** de l'analyse.

---

## 🗂️ Structure du projet

```
📁 projet-geopolitique/
│
├── 📄 rapport.Rmd              # Source principale du rapport (R Markdown)
├── 📄 rapport.html             # Rapport compilé (knit)
├── 📄 README.md                # Ce fichier
│
└── 📁 data/
    └── data_clean.csv          # Dataset principal (à placer ici avant de knit)
```

---

## 📊 Dataset

| Dimension | Détail |
|-----------|--------|
| **Fichier** | `data_clean.csv` |
| **Période** | 1948 – 2024 |
| **Pays** | USA · Israël · Iran |
| **Sources** | Banque Mondiale · SIPRI · EIA · UCDP · IISS · Kaggle |

> ⚠️ **Important :** avant de compiler le rapport, vérifiez que le chemin vers `data_clean.csv` dans le chunk `setup` correspond bien à votre environnement local :
> ```r
> PATH_DATA <- "C:/Users/VOTRE_NOM/Downloads/Rapport stat/data/data_clean.csv"
> ```

---

## 🧩 Modules du rapport

| # | Module | Méthode |
|---|--------|---------|
| 1 | Analyse temporelle 1948–2024 | Visualisation séries temporelles |
| 2 | Comparaison pays | Violin plots · K-means (k=4) |
| 3 | Analyse militaire | Scatter · Time series |
| 4 | Pétrole, inflation & conflits | Double axe · Régression |
| 5 | Analyse avant/après événements | Fenêtre ±5 ans (USA) |
| 6 | Matrice de corrélation | Pearson · `ggcorrplot` |
| 7 | Profils par période de conflit | Facettes par pays |
| 8 | Régression linéaire multiple | Brent · Inflation Iran |
| 9 | Classification Random Forest | `randomForest` · Arbre de décision |
| 10 | ACP | `FactoMineR` · Biplot · Scree plot |
| 11 | K-means (k=3) | Méthode du coude · Silhouette |
| 12 | CAH | Ward · Dendrogramme |
| 13 | **Impact Business** | Énergie · Finance · Supply Chain |

---

## ⚙️ Prérequis et installation

### Logiciels nécessaires

- [R](https://cran.r-project.org/) ≥ 4.2.0
- [RStudio](https://posit.co/download/rstudio-desktop/) (recommandé)

### Packages R

Les packages sont installés automatiquement au premier lancement via le chunk `setup`. Liste complète :

```r
c("tidyverse", "ggplot2", "scales", "patchwork",
  "ggcorrplot", "factoextra", "cluster", "FactoMineR",
  "randomForest", "caret", "rpart", "rpart.plot",
  "ggrepel", "viridis", "knitr", "kableExtra")
```

---

## 🚀 Lancer le rapport

1. **Cloner le dépôt** :
   ```bash
   git clone https://github.com/votre-utilisateur/nom-du-repo.git
   cd nom-du-repo
   ```

2. **Placer le dataset** dans `data/data_clean.csv`

3. **Mettre à jour le chemin** dans `rapport.Rmd` (chunk `setup`, variable `PATH_DATA`)

4. **Compiler le rapport** depuis RStudio :
   - Ouvrir `rapport.Rmd`
   - Cliquer sur **Knit → Knit to HTML**

   Ou depuis la console R :
   ```r
   rmarkdown::render("rapport.Rmd")
   ```

5. Le fichier `rapport.html` est généré dans le même dossier.

---

## 📌 Résultats clés

- 📈 Le prix du Brent est **30 à 40 $/baril plus élevé** en période de conflit intense
- 🎯 Le Random Forest classe les périodes géopolitiques avec une **accuracy > 85%**
- 🔍 K-means et CAH **convergent vers 3 clusters** correspondant aux phases historiques
- 💸 Les **sanctions financières** déstabilisent davantage l'économie iranienne que les conflits militaires directs

---

## 📚 Références principales

- Banque Mondiale — *World Development Indicators* (2024)
- SIPRI — *Military Expenditure Database* (2024)
- U.S. EIA — *Europe Brent Spot Price FOB* (2024)
- UCDP — *Uppsala Conflict Data Program v23.1* (2024)
- Kaggle — Lodhra, A. (2024) · Shanali, M. (2024)

---

## 📄 Licence

Projet académique — Tek-Up University · 2024–2025.  
Usage éducatif uniquement. Les données proviennent de sources publiques citées ci-dessus.

---

<div align="center">
  <sub>Fatma Ayadi & Arij Khemiri · Tek-Up University · Pr. Ahmed Dhouibi · 2025</sub>
</div>