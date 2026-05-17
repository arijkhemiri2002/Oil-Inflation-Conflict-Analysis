library(tidyverse)
library(readr)

# ── CHARGEMENT ────────────────────────────────────────────

df <- read.csv("C:/Users/arijk/Desktop/Rapport stat/data.csv")

copie <- df

# ── SÉLECTION DES COLONNES ────────────────────────────────

copie <- copie %>%
  select(
    GDP_Growth_Percent,
    GDP_current_USD,
    Active_Personnel,
    Military_Expenditure_Billion_USD,
    country,
    year,
    periode,
    Significant_Event,
    Conflict_Severity_Index,
    Brent_Oil_Price_USD_per_barrel,
    Unemployment_total_pct,
    Inflation_Rate_Percent
  )

# ── TRI DES DONNÉES ───────────────────────────────────────

copie <- copie %>%
  arrange(country, year)

# ──────────────────────────────────────────────────────────
# FONCTION GM(1,1)
# ──────────────────────────────────────────────────────────
gm11_predict <- function(x, n_pred = 1) {
  
  x <- as.numeric(x)
  
  # enlever NA
  x <- x[!is.na(x)]
  
  # minimum de valeurs
  if(length(x) < 4) {
    return(rep(NA, length(x) + n_pred))
  }
  
  # éviter séries constantes
  if(sd(x) == 0) {
    return(rep(mean(x), length(x) + n_pred))
  }
  
  tryCatch({
    
    # AGO
    x1 <- cumsum(x)
    
    # moyenne adjacente
    z1 <- (x1[-1] + x1[-length(x1)]) / 2
    
    # matrices
    B <- cbind(-z1, 1)
    Y <- matrix(x[-1], ncol = 1)
    
    # vérifier singularité
    det_val <- det(t(B) %*% B)
    
    if(abs(det_val) < 1e-10) {
      return(rep(mean(x), length(x) + n_pred))
    }
    
    # paramètres
    params <- solve(t(B) %*% B) %*% t(B) %*% Y
    
    a <- params[1]
    b <- params[2]
    
    # prédiction
    f_hat <- function(k) {
      (x[1] - b/a) * exp(-a * (k - 1)) + b/a
    }
    
    x1_hat <- sapply(1:(length(x) + n_pred), f_hat)
    
    x0_hat <- c(x[1], diff(x1_hat))
    
    return(as.numeric(x0_hat))
    
  }, error = function(e) {
    
    # fallback = moyenne
    return(rep(mean(x), length(x) + n_pred))
  })
}

# ──────────────────────────────────────────────────────────
# IMPUTATION GM(1,1)
# ──────────────────────────────────────────────────────────

impute_grey <- function(data, variable) {
  
  data %>%
    group_by(country) %>%
    group_modify(~{
      
      df_country <- .x
      
      values <- df_country[[variable]]
      
      # indices non NA
      known_idx <- which(!is.na(values))
      
      # minimum 4 valeurs nécessaires
      if(length(known_idx) < 4) {
        return(df_country)
      }
      
      known_values <- values[known_idx]
      
      # prédiction GM
      gm_pred <- gm11_predict(known_values,
                              n_pred = sum(is.na(values)))
      
      # récupérer uniquement les nouvelles prédictions
      predicted_values <- gm_pred[(length(known_values)+1):
                                    length(gm_pred)]
      
      # remplacer les NA
      na_idx <- which(is.na(values))
      
      values[na_idx] <- predicted_values[1:length(na_idx)]
      
      df_country[[variable]] <- values
      
      return(df_country)
    }) %>%
    ungroup()
}

# ──────────────────────────────────────────────────────────
# VARIABLES À IMPUTER
# ──────────────────────────────────────────────────────────

cols_impute <- c(
  "GDP_current_USD",
  "Brent_Oil_Price_USD_per_barrel",
  "Unemployment_total_pct"
)

# ──────────────────────────────────────────────────────────
# APPLICATION DE L’IMPUTATION
# ──────────────────────────────────────────────────────────

for(col in cols_impute){
  
  copie <- impute_grey(copie, col)
  
  cat("Imputation GM(1,1) terminée pour :", col, "\n")
}

# ──────────────────────────────────────────────────────────
# VÉRIFICATION
# ──────────────────────────────────────────────────────────

colSums(is.na(copie))

# ──────────────────────────────────────────────────────────
# COMPLÉTER LES NA RESTANTS PAR MÉDIANE
# ──────────────────────────────────────────────────────────

for(col in cols_impute){
  
  median_val <- median(copie[[col]], na.rm = TRUE)
  
  copie[[col]][is.na(copie[[col]])] <- median_val
  
  cat("NA restants remplacés par médiane pour :", col, "\n")
}

# Vérification finale
colSums(is.na(copie))

# ──────────────────────────────────────────────────────────
# APERÇU
# ──────────────────────────────────────────────────────────

head(copie)


# ── DÉTECTION DES OUTLIERS (IQR) ──────────────────────────
detect_outliers_iqr <- function(x, col_name) {
  Q1      <- quantile(x, 0.25, na.rm = TRUE)
  Q3      <- quantile(x, 0.75, na.rm = TRUE)
  IQR_val <- Q3 - Q1
  lower   <- Q1 - 1.5 * IQR_val
  upper   <- Q3 + 1.5 * IQR_val
  outliers <- x[x < lower | x > upper]
  
  cat(sprintf("\n── %s ──\n", col_name))
  cat(sprintf("  Q1 = %.2f | Q3 = %.2f | IQR = %.2f\n", Q1, Q3, IQR_val))
  cat(sprintf("  Borne inf = %.2f | Borne sup = %.2f\n", lower, upper))
  cat(sprintf("  Nombre d'outliers : %d (%.1f%%)\n",
              length(outliers),
              length(outliers) / length(x) * 100))
}

# Appliquer sur toutes les colonnes numériques
cols_numeric <- copie %>%
  select(where(is.numeric)) %>%
  names()

for (col in cols_numeric) {
  detect_outliers_iqr(copie[[col]], col)
}

# ── BOXPLOTS ──────────────────────────────────────────────
copie %>%
  select(all_of(cols_numeric)) %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "valeur") %>%
  ggplot(aes(x = variable, y = valeur, fill = variable)) +
  geom_boxplot(outlier.colour = "red", outlier.size = 2) +
  facet_wrap(~variable, scales = "free") +
  theme_minimal() +
  labs(title = "Détection des Outliers par Boxplot", x = "", y = "") +
  theme(legend.position = "none",
        axis.text.x = element_blank())

#______Remplace les outliers par les bornes IQR ____________________

winsorize <- function(df, cols) {
  df_wins <- df
  
  for (col in cols) {
    Q1      <- quantile(df_wins[[col]], 0.25, na.rm = TRUE)
    Q3      <- quantile(df_wins[[col]], 0.75, na.rm = TRUE)
    IQR_val <- Q3 - Q1
    lower   <- Q1 - 1.5 * IQR_val
    upper   <- Q3 + 1.5 * IQR_val
    
    n_wins <- sum(df_wins[[col]] < lower | df_wins[[col]] > upper, na.rm = TRUE)
    
    df_wins[[col]] <- pmax(pmin(df_wins[[col]], upper), lower)
    
    cat(sprintf("%-35s → %d valeurs winsorisées\n", col, n_wins))
  }
  
  return(df_wins)
}

copie_clean <- winsorize(copie, cols_numeric)

# ── EXPORT CSV ────────────────────────────────────────────
write_csv(copie_clean, "data_clean.csv")


cat("Export CSV réussi !")


