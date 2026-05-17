# ============================================================
#  ANALYSE GÉOPOLITIQUE & ÉCONOMIQUE — USA, ISRAËL & IRAN
#  1948–2024
# ============================================================
#  Variables : PIB, croissance, dépenses militaires, personnel,
#  inflation, chômage, pétrole, indice de conflit, événements
# ============================================================


# ════════════════════════════════════════════════════════════
#  0. CONFIGURATION GLOBALE
# ════════════════════════════════════════════════════════════

# ── 0.1 Packages ────────────────────────────────────────────
required_packages <- c(
  "tidyverse", "ggplot2", "scales", "patchwork",
  "ggcorrplot", "factoextra", "cluster", "FactoMineR",
  "randomForest", "caret", "rpart", "rpart.plot",
  "ggrepel", "viridis"
)

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
invisible(lapply(required_packages, install_if_missing))
invisible(lapply(required_packages, library, character.only = TRUE))

# ── 0.2 Chemins ─────────────────────────────────────────────
PATH_DATA   <- "C:/Users/arijk/Desktop/Rapport stat/data_clean.csv"
PATH_OUTPUT <- "C:/Users/arijk/Desktop/Rapport stat/outputs/"
dir.create(PATH_OUTPUT, showWarnings = FALSE, recursive = TRUE)

save_plot <- function(filename, plot = last_plot(), width = 12, height = 8, dpi = 150) {
  ggsave(file.path(PATH_OUTPUT, filename), plot = plot,
         width = width, height = height, dpi = dpi)
  cat("  →", filename, "sauvegardé\n")
}

# ── 0.3 Chargement des données ──────────────────────────────
df <- read.csv(PATH_DATA, stringsAsFactors = FALSE)

# Uniformisation des noms de colonnes attendus dans tout le script
# Adapter si votre CSV utilise des noms différents
df <- df %>%
  rename_with(~ case_when(
    . == "GDP_growth_annual_pct"                    ~ "GDP_Growth_Percent",
    . == "Inflation_consumer_prices_annual_pct"     ~ "Inflation_Rate_Percent",
    TRUE                                            ~ .
  ))

cat("Dataset chargé :", nrow(df), "observations,", ncol(df), "variables\n")
cat("   Pays     :", paste(sort(unique(df$country)), collapse = ", "), "\n")
cat("   Période  :", min(df$year, na.rm = TRUE), "–", max(df$year, na.rm = TRUE), "\n\n")

# ── 0.4 Palettes & thème communs ────────────────────────────
palette_pays   <- c("USA" = "#185FA5", "Israel" = "#D85A30", "Iran" = "#639922")
palette_period <- c("Paix" = "#639922", "Conflit modéré" = "#EF9F27",
                    "Conflit intense" = "#E24B4A")
palette_cluster <- c("Cluster 1" = "#1D9E75", "Cluster 2" = "#BA7517",
                     "Cluster 3" = "#E24B4A")

theme_geo <- theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(color = "gray50", size = 10),
    axis.title       = element_text(size = 10),
    legend.position  = "bottom",
    legend.title     = element_text(size = 9),
    panel.grid.minor = element_blank(),
    strip.text       = element_text(face = "bold")
  )

# Colonnes numériques réutilisées dans ACP / clustering
FEATURES_NUM <- c(
  "Military_Expenditure_Billion_USD", "Active_Personnel",
  "Conflict_Severity_Index", "GDP_current_USD",
  "GDP_Growth_Percent",
  "Brent_Oil_Price_USD_per_barrel", "Inflation_Rate_Percent",
  "Unemployment_total_pct"
)


# ════════════════════════════════════════════════════════════
#  MODULE 1 : ANALYSE TEMPORELLE
# ════════════════════════════════════════════════════════════
cat("── Module 1 : Analyse temporelle ──────────────────────\n")

# Zones de conflit intense pour annotation
df_conflict_zones <- df %>%
  filter(Conflict_Severity_Index == 5) %>%
  group_by(country) %>%
  summarise(xmin = min(year), xmax = max(year), .groups = "drop")

p1a <- df %>%
  ggplot(aes(x = year, y = GDP_Growth_Percent, color = country)) +
  geom_rect(data = df_conflict_zones,
            aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = country),
            alpha = 0.08, inherit.aes = FALSE) +
  geom_line(linewidth = 0.8, alpha = 0.85) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
  scale_color_manual(values = palette_pays) +
  scale_fill_manual(values = palette_pays) +
  labs(title = "Croissance du PIB (%)",
       subtitle = "Zones colorées = périodes de conflit intense",
       x = NULL, y = "Croissance PIB (%)", color = "Pays", fill = "Pays") +
  theme_geo

p1b <- df %>%
  ggplot(aes(x = year, y = Conflict_Severity_Index, fill = country)) +
  geom_area(alpha = 0.55, position = "identity") +
  scale_fill_manual(values = palette_pays) +
  labs(title = "Indice de conflit dans le temps",
       x = NULL, y = "Indice de conflit (0–5)", fill = "Pays") +
  theme_geo

p1c <- df %>%
  ggplot(aes(x = year, y = Inflation_Rate_Percent, color = country)) +
  geom_line(linewidth = 0.7, alpha = 0.85) +
  geom_smooth(method = "loess", span = 0.3, se = FALSE,
              linetype = "dashed", linewidth = 0.5) +
  scale_color_manual(values = palette_pays) +
  labs(title = "Inflation (%)",
       x = NULL, y = "Inflation (%)", color = "Pays") +
  theme_geo

plot_temporal <- (p1a / p1b / p1c) +
  plot_annotation(title = "ANALYSE TEMPORELLE 1948–2024",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("01_analyse_temporelle.png", plot_temporal, width = 14, height = 12)


# ════════════════════════════════════════════════════════════
#  MODULE 2 : COMPARAISON PAYS & CLUSTERING
# ════════════════════════════════════════════════════════════
cat("── Module 2 : Comparaison pays & clustering ────────────\n")

# 2a — Distribution des variables clés par pays
vars_compare <- c("GDP_Growth_Percent", "Inflation_Rate_Percent",
                  "Unemployment_total_pct", "Conflict_Severity_Index")

labels_vars <- c(
  GDP_Growth_Percent      = "Croissance PIB (%)",
  Inflation_Rate_Percent  = "Inflation (%)",
  Unemployment_total_pct  = "Chômage (%)",
  Conflict_Severity_Index = "Indice conflit"
)

p2a <- df %>%
  select(country, year, all_of(vars_compare)) %>%
  pivot_longer(cols = all_of(vars_compare), names_to = "variable", values_to = "valeur") %>%
  mutate(variable = recode(variable, !!!labels_vars)) %>%
  ggplot(aes(x = country, y = valeur, fill = country)) +
  geom_violin(alpha = 0.45, trim = FALSE) +
  geom_boxplot(width = 0.15, outlier.size = 0.8, alpha = 0.8) +
  scale_fill_manual(values = palette_pays) +
  facet_wrap(~variable, scales = "free_y", ncol = 2) +
  labs(title = "Distribution des variables clés par pays",
       x = NULL, y = NULL, fill = "Pays") +
  theme_geo + theme(legend.position = "none")

# 2b — K-means : préparation robuste (variance nulle + NaN)
df_cluster_raw <- df %>%
  select(country, year, all_of(vars_compare),
         Military_Expenditure_Billion_USD) %>%
  na.omit()

df_cluster_num <- df_cluster_raw %>%
  select(where(is.numeric)) %>%
  select(where(~ var(., na.rm = TRUE) > 0))   # supprime colonnes constantes

df_cluster_scaled <- as.data.frame(
  apply(df_cluster_num, 2, function(x) {
    s <- as.numeric(scale(x))
    s[!is.finite(s)] <- 0
    s
  })
)

set.seed(42)
km2 <- kmeans(df_cluster_scaled, centers = 4, nstart = 25)
df_cluster_raw$cluster <- factor(km2$cluster,
                                 labels = paste("Cluster", 1:4))

p2b <- fviz_cluster(km2,
                    data         = df_cluster_scaled,
                    geom         = "point",
                    ellipse.type = "convex",
                    palette      = c("#185FA5", "#D85A30", "#639922", "#BA7517"),
                    ggtheme      = theme_geo) +
  labs(title = "K-means (k=4) — Profils annuels")

plot_pays <- (p2a | p2b) +
  plot_annotation(title = "COMPARAISON PAYS & CLUSTERING",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("02_comparaison_pays.png", plot_pays, width = 16, height = 9)


# ════════════════════════════════════════════════════════════
#  MODULE 3 : ANALYSE MILITAIRE
# ════════════════════════════════════════════════════════════
cat("── Module 3 : Analyse militaire ───────────────────────\n")

p3a <- df %>%
  ggplot(aes(x = year, y = Military_Expenditure_Billion_USD, color = country)) +
  geom_line(linewidth = 1) +
  geom_point(data = df %>% filter(Significant_Event != "None"),
             aes(shape = Significant_Event), size = 2.5) +
  scale_color_manual(values = palette_pays) +
  labs(title = "Dépenses militaires (Mrd $)",
       subtitle = "Points = événements majeurs",
       x = NULL, y = "Mrd USD", color = "Pays", shape = "Événement") +
  theme_geo

p3b <- df %>%
  ggplot(aes(x = Conflict_Severity_Index,
             y = Military_Expenditure_Billion_USD,
             color = country, size = Active_Personnel)) +
  geom_jitter(alpha = 0.55, width = 0.15) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 0.8, show.legend = FALSE) +
  scale_color_manual(values = palette_pays) +
  scale_size_continuous(labels = comma) +
  labs(title = "Dépenses militaires vs Indice de conflit",
       x = "Indice de conflit (0–5)", y = "Mrd USD",
       color = "Pays", size = "Personnel actif") +
  theme_geo

p3c <- df %>%
  ggplot(aes(x = year, y = Active_Personnel / 1e6, color = country)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = function(x) paste0(round(x, 1), "M")) +
  scale_color_manual(values = palette_pays) +
  labs(title = "Personnel militaire actif",
       x = NULL, y = "Millions", color = "Pays") +
  theme_geo

plot_mil <- (p3a / (p3b | p3c)) +
  plot_annotation(title = "ANALYSE MILITAIRE",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("03_analyse_militaire.png", plot_mil, width = 16, height = 11)


# ════════════════════════════════════════════════════════════
#  MODULE 4 : PÉTROLE, INFLATION & CONFLITS
# ════════════════════════════════════════════════════════════
cat("── Module 4 : Pétrole & Inflation ─────────────────────\n")

df_oil <- df %>%
  group_by(year) %>%
  summarise(
    brent    = mean(Brent_Oil_Price_USD_per_barrel, na.rm = TRUE),
    inf_usa  = mean(Inflation_Rate_Percent[country == "USA"],    na.rm = TRUE),
    inf_isr  = mean(Inflation_Rate_Percent[country == "Israel"], na.rm = TRUE),
    inf_ir   = mean(Inflation_Rate_Percent[country == "Iran"],   na.rm = TRUE),
    csi_mean = mean(Conflict_Severity_Index, na.rm = TRUE),
    .groups = "drop"
  )

coeff_scale <- max(df_oil$inf_usa, na.rm = TRUE) /
  max(df_oil$brent,   na.rm = TRUE)

p4a <- df_oil %>%
  ggplot(aes(x = year)) +
  geom_line(aes(y = brent,           color = "Brent ($/baril)"),   linewidth = 1) +
  geom_line(aes(y = inf_usa / coeff_scale, color = "Inflation USA"),   linetype = "dashed") +
  geom_line(aes(y = inf_isr / coeff_scale, color = "Inflation Israël"), linetype = "dotted") +
  geom_line(aes(y = inf_ir  / coeff_scale, color = "Inflation Iran"),   linetype = "dotdash") +
  scale_y_continuous(
    name     = "Prix du Brent ($/baril)",
    sec.axis = sec_axis(~ . * coeff_scale, name = "Inflation (%)")
  ) +
  scale_color_manual(values = c(
    "Brent ($/baril)"  = "#BA7517",
    "Inflation USA"    = "#185FA5",
    "Inflation Israël" = "#D85A30",
    "Inflation Iran"   = "#639922"
  )) +
  labs(title = "Prix du Brent vs Inflation (USA, Israël, Iran)",
       x = NULL, color = NULL) +
  theme_geo

p4b <- df_oil %>%
  ggplot(aes(x = csi_mean, y = brent)) +
  geom_point(aes(color = brent), size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "#BA7517") +
  scale_color_viridis_c(option = "C", name = "Brent ($)") +
  labs(title = "Indice de conflit moyen vs Prix du Brent",
       x = "Indice de conflit moyen", y = "Prix Brent ($/baril)") +
  theme_geo

plot_oil <- (p4a / p4b) +
  plot_annotation(title = "PÉTROLE, INFLATION & CONFLITS",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("04_petrole_inflation.png", plot_oil, width = 14, height = 10)


# ════════════════════════════════════════════════════════════
#  MODULE 5 : ANALYSE AVANT / APRÈS ÉVÉNEMENTS (USA)
# ════════════════════════════════════════════════════════════
cat("── Module 5 : Analyse avant/après événements ──────────\n")

events_usa <- c("Korean War" = 1950, "Vietnam War" = 1965,
                "Gulf War"   = 1991, "War on Terror" = 2001)

vars_event <- c("GDP_Growth_Percent", "Inflation_Rate_Percent",
                "Unemployment_total_pct", "Military_Expenditure_Billion_USD")

df_event_analysis <- map_dfr(names(events_usa), function(ev) {
  yr     <- events_usa[ev]
  window <- 5
  df_usa <- df %>% filter(country == "USA")
  bind_rows(
    df_usa %>% filter(year %in% (yr - window):(yr - 1)) %>%
      summarise(across(all_of(vars_event), ~ mean(., na.rm = TRUE))) %>%
      mutate(evenement = ev, periode_rel = "Avant"),
    df_usa %>% filter(year %in% yr:(yr + window)) %>%
      summarise(across(all_of(vars_event), ~ mean(., na.rm = TRUE))) %>%
      mutate(evenement = ev, periode_rel = "Pendant/Après")
  )
})

labels_event <- c(
  GDP_Growth_Percent               = "Croissance PIB (%)",
  Inflation_Rate_Percent           = "Inflation (%)",
  Unemployment_total_pct           = "Chômage (%)",
  Military_Expenditure_Billion_USD = "Dép. militaires (Mrd $)"
)

p5 <- df_event_analysis %>%
  pivot_longer(cols = all_of(vars_event), names_to = "variable", values_to = "valeur") %>%
  mutate(variable = recode(variable, !!!labels_event)) %>%
  ggplot(aes(x = periode_rel, y = valeur, fill = periode_rel)) +
  geom_col(position = "dodge", width = 0.65) +
  facet_grid(variable ~ evenement, scales = "free_y") +
  scale_fill_manual(values = c("Avant" = "#639922", "Pendant/Après" = "#E24B4A")) +
  labs(title = "Effet des conflits majeurs — Analyse avant/après (USA)",
       subtitle = "Fenêtre de ±5 ans autour de l'année de déclenchement",
       x = NULL, y = NULL, fill = NULL) +
  theme_geo +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

save_plot("05_avant_apres_conflits.png", p5, width = 16, height = 11)


# ════════════════════════════════════════════════════════════
#  MODULE 6 : MATRICE DE CORRÉLATION
# ════════════════════════════════════════════════════════════
cat("── Module 6 : Corrélations ─────────────────────────────\n")

vars_corr <- c("GDP_Growth_Percent", "Military_Expenditure_Billion_USD",
               "Active_Personnel", "Inflation_Rate_Percent",
               "Unemployment_total_pct", "Brent_Oil_Price_USD_per_barrel",
               "Conflict_Severity_Index")

labels_corr <- c("Croiss. PIB", "Dép. Mil.", "Personnel",
                 "Inflation", "Chômage", "Brent", "Conflit")

corr_mat <- df %>%
  select(all_of(vars_corr)) %>%
  na.omit() %>%
  setNames(labels_corr) %>%
  cor()

p6 <- ggcorrplot(corr_mat,
                 method   = "circle",
                 type     = "lower",
                 lab      = TRUE,
                 lab_size = 3.5,
                 colors   = c("#D85A30", "white", "#185FA5"),
                 title    = "Matrice de corrélation — Variables géopolitiques & économiques",
                 ggtheme  = theme_geo
)

save_plot("06_correlation_matrix.png", p6, width = 9, height = 8)


# ════════════════════════════════════════════════════════════
#  MODULE 7 : ANALYSE PAR PÉRIODE
# ════════════════════════════════════════════════════════════
cat("── Module 7 : Analyse par période ─────────────────────\n")

df_period_summary <- df %>%
  group_by(periode, country) %>%
  summarise(
    moy_croissance = mean(GDP_Growth_Percent,              na.rm = TRUE),
    moy_inflation  = mean(Inflation_Rate_Percent,          na.rm = TRUE),
    moy_chomage    = mean(Unemployment_total_pct,          na.rm = TRUE),
    moy_conflit    = mean(Conflict_Severity_Index,         na.rm = TRUE),
    moy_mil        = mean(Military_Expenditure_Billion_USD, na.rm = TRUE),
    .groups = "drop"
  )

labels_period <- c(
  moy_croissance = "Croissance PIB (%)",
  moy_inflation  = "Inflation (%)",
  moy_chomage    = "Chômage (%)",
  moy_conflit    = "Indice conflit",
  moy_mil        = "Dép. mil. (Mrd $)"
)

p7 <- df_period_summary %>%
  pivot_longer(cols = starts_with("moy_"), names_to = "indicator", values_to = "valeur") %>%
  mutate(indicator = recode(indicator, !!!labels_period),
         periode   = factor(periode,
                            levels = c("Paix", "Conflit modéré", "Conflit intense"))) %>%
  ggplot(aes(x = periode, y = valeur, fill = country)) +
  geom_col(position = "dodge", width = 0.7) +
  facet_wrap(~indicator, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = palette_pays) +
  labs(title = "Profil économique & militaire par période de conflit",
       x = NULL, y = NULL, fill = "Pays") +
  theme_geo +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_plot("07_analyse_periode.png", p7, width = 14, height = 10)


# ════════════════════════════════════════════════════════════
#  MODULE 8 : MACHINE LEARNING — RÉGRESSION (Brent & Inflation)
# ════════════════════════════════════════════════════════════
cat("── Module 8 : Régression ───────────────────────────────\n")

# 8a — Régression : prix du Brent
df_brent_ml <- df %>%
  select(Military_Expenditure_Billion_USD, Active_Personnel,
         Conflict_Severity_Index, GDP_current_USD, country, year,
         Brent_Oil_Price_USD_per_barrel) %>%
  drop_na()

set.seed(42)
idx_b    <- createDataPartition(df_brent_ml$Brent_Oil_Price_USD_per_barrel,
                                p = 0.8, list = FALSE)
train_b  <- df_brent_ml[idx_b, ]
test_b   <- df_brent_ml[-idx_b, ]

model_brent <- lm(Brent_Oil_Price_USD_per_barrel ~ ., data = train_b)
pred_brent  <- predict(model_brent, newdata = test_b)
r2_brent    <- cor(pred_brent, test_b$Brent_Oil_Price_USD_per_barrel)^2
mae_brent   <- mean(abs(pred_brent - test_b$Brent_Oil_Price_USD_per_barrel))
cat(sprintf("  Brent — R² = %.3f | MAE = %.2f USD\n", r2_brent, mae_brent))

p8a <- data.frame(reel = test_b$Brent_Oil_Price_USD_per_barrel, predit = pred_brent) %>%
  ggplot(aes(x = reel, y = predit)) +
  geom_point(color = "#BA7517", size = 2.5, alpha = 0.75) +
  geom_abline(slope = 1, intercept = 0, color = "#185FA5", linetype = "dashed") +
  labs(title = sprintf("Brent — Réel vs Prédit  (R²=%.3f | MAE=%.1f $)", r2_brent, mae_brent),
       x = "Valeur réelle ($/baril)", y = "Valeur prédite ($/baril)") +
  theme_geo

# 8b — Régression : inflation Iran
df_inf_ml <- df %>%
  filter(country == "Iran") %>%
  select(Military_Expenditure_Billion_USD, Conflict_Severity_Index,
         GDP_Growth_Percent,
         Brent_Oil_Price_USD_per_barrel, Unemployment_total_pct,
         Inflation_Rate_Percent) %>%
  drop_na()

set.seed(42)
idx_i    <- createDataPartition(df_inf_ml$Inflation_Rate_Percent, p = 0.8, list = FALSE)
train_i  <- df_inf_ml[idx_i, ]
test_i   <- df_inf_ml[-idx_i, ]

model_inf <- lm(Inflation_Rate_Percent ~ ., data = train_i)
pred_inf  <- predict(model_inf, newdata = test_i)
r2_inf    <- cor(pred_inf, test_i$Inflation_Rate_Percent)^2
mae_inf   <- mean(abs(pred_inf - test_i$Inflation_Rate_Percent))
cat(sprintf("  Inflation Iran — R² = %.3f | MAE = %.2f %%\n", r2_inf, mae_inf))

p8b <- data.frame(reel = test_i$Inflation_Rate_Percent, predit = pred_inf) %>%
  ggplot(aes(x = reel, y = predit)) +
  geom_point(color = "#E24B4A", size = 2.5, alpha = 0.75) +
  geom_abline(slope = 1, intercept = 0, color = "#185FA5", linetype = "dashed") +
  labs(title = sprintf("Inflation Iran — Réel vs Prédit  (R²=%.3f)", r2_inf),
       x = "Inflation réelle (%)", y = "Inflation prédite (%)") +
  theme_geo

plot_reg <- (p8a | p8b) +
  plot_annotation(title = "RÉGRESSION LINÉAIRE",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("08_regression.png", plot_reg, width = 14, height = 6)


# ════════════════════════════════════════════════════════════
#  MODULE 9 : MACHINE LEARNING — CLASSIFICATION (Random Forest)
# ════════════════════════════════════════════════════════════
cat("── Module 9 : Classification Random Forest ─────────────\n")

df$country_num <- recode(df$country,
                         "USA" = 1,
                         "Israel" = 2,
                         "Iran" = 3)

df_clf <- df %>%
  select(Military_Expenditure_Billion_USD, Conflict_Severity_Index,
         GDP_Growth_Percent, Brent_Oil_Price_USD_per_barrel,
         Inflation_Rate_Percent, Active_Personnel,
         country_num, periode) %>%
  drop_na() %>%
  mutate(periode = factor(periode,
                          levels = c("Paix", "Conflit modéré", "Conflit intense")))

set.seed(42)
idx_c   <- createDataPartition(df_clf$periode, p = 0.8, list = FALSE)
train_c <- df_clf[idx_c, ]
test_c  <- df_clf[-idx_c, ]

rf_model <- randomForest(periode ~ ., data = train_c, ntree = 300, importance = TRUE)
pred_c   <- predict(rf_model, newdata = test_c)
cm_rf    <- confusionMatrix(pred_c, test_c$periode)
cat(sprintf("  Random Forest — Accuracy = %.1f%%\n", cm_rf$overall["Accuracy"] * 100))

# Importance des variables
imp_df <- importance(rf_model) %>%
  as.data.frame() %>%
  rownames_to_column("variable") %>%
  arrange(desc(MeanDecreaseGini))

p9a <- imp_df %>%
  ggplot(aes(x = reorder(variable, MeanDecreaseGini),
             y = MeanDecreaseGini, fill = MeanDecreaseGini)) +
  geom_col(show.legend = FALSE) +
  scale_fill_gradient(low = "#E6F1FB", high = "#185FA5") +
  coord_flip() +
  labs(title = "Random Forest — Importance des variables",
       subtitle = "Prédiction de la période de conflit",
       x = NULL, y = "Mean Decrease Gini") +
  theme_geo

# Matrice de confusion
cm_df <- as.data.frame(cm_rf$table)
p9b <- cm_df %>%
  ggplot(aes(x = Reference, y = Prediction, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), size = 4, fontface = "bold") +
  scale_fill_gradient(low = "white", high = "#185FA5") +
  labs(title = sprintf("Matrice de confusion (Accuracy : %.1f%%)",
                       cm_rf$overall["Accuracy"] * 100),
       x = "Valeur réelle", y = "Prédiction", fill = "N") +
  theme_geo

plot_clf <- (p9a | p9b) +
  plot_annotation(title = "CLASSIFICATION — RANDOM FOREST",
                  theme = theme(plot.title = element_text(face = "bold", size = 15)))

save_plot("09_classification_rf.png", plot_clf, width = 14, height = 7)

# Arbre de décision (interprétable)
tree_model <- rpart(periode ~ ., data = train_c, method = "class",
                    control = rpart.control(maxdepth = 4))

png(file.path(PATH_OUTPUT, "10_arbre_decision.png"), width = 1400, height = 900, res = 130)
rpart.plot(tree_model, type = 4, extra = 104, box.palette = "auto",
           main = "Arbre de décision — Classification des périodes")
dev.off()
cat("  → 10_arbre_decision.png sauvegardé\n")


# ════════════════════════════════════════════════════════════
#  MODULE 10 : ACP (FactoMineR)
# ════════════════════════════════════════════════════════════
cat("── Module 10 : ACP FactoMineR ─────────────────────────\n")

df_pca <- df %>%
  select(country, year, periode, all_of(FEATURES_NUM)) %>%
  drop_na()

# Variables qualitatives en supplémentaires (non intégrées au calcul)
quali_cols <- which(names(df_pca) %in% c("country", "periode", "year"))

acp <- PCA(df_pca, scale.unit = TRUE, quali.sup = quali_cols, graph = FALSE)

cat("\nVariance expliquée par axe :\n")
print(round(acp$eig, 3))

# Scree plot
p10a <- fviz_eig(acp, addlabels = TRUE, ylim = c(0, 60),
                 barfill = "#185FA5", barcolor = "#185FA5",
                 linecolor = "#E24B4A") +
  labs(title = "Scree plot — Variance expliquée par axe (règle de Kaiser : valeur propre > 1)",
       x = "Composantes principales", y = "% variance expliquée") +
  theme_geo

save_plot("11_scree_plot.png", p10a, width = 8, height = 5)

# Cercle des corrélations
p10b <- fviz_pca_var(acp, col.var = "cos2",
                     gradient.cols = c("#E6F1FB", "#185FA5", "#0C447C"),
                     repel = TRUE, legend.title = "Cos²") +
  labs(title = "ACP — Cercle des corrélations (cos² = qualité de représentation)") +
  theme_geo

save_plot("12_cercle_correlations.png", p10b, width = 8, height = 7)

# Contributions PC1 et PC2
p10c <- fviz_contrib(acp, choice = "var", axes = 1,
                     fill = "#185FA5", color = "#185FA5") +
  labs(title = "Contributions des variables à PC1") + theme_geo

p10d <- fviz_contrib(acp, choice = "var", axes = 2,
                     fill = "#BA7517", color = "#BA7517") +
  labs(title = "Contributions des variables à PC2") + theme_geo

save_plot("13_contrib_PC1.png", p10c, width = 10, height = 5)
save_plot("14_contrib_PC2.png", p10d, width = 10, height = 5)

# Individus colorés par pays
p10e <- fviz_pca_ind(acp, geom.ind = "point",
                     col.ind = df_pca$country,
                     palette = palette_pays,
                     addEllipses = TRUE, ellipse.type = "convex",
                     legend.title = "Pays", repel = FALSE) +
  labs(title = "ACP — Individus colorés par pays") + theme_geo

# Individus colorés par période
p10f <- fviz_pca_ind(acp, geom.ind = "point",
                     col.ind = df_pca$periode,
                     palette = palette_period,
                     addEllipses = TRUE, ellipse.type = "convex",
                     legend.title = "Période") +
  labs(title = "ACP — Individus colorés par période de conflit") + theme_geo

save_plot("15_acp_pays.png",    p10e, width = 9, height = 7)
save_plot("16_acp_periode.png", p10f, width = 9, height = 7)

# Biplot
p10g <- fviz_pca_biplot(acp, col.ind = df_pca$country,
                        palette = palette_pays,
                        col.var = "black", label = "var",
                        repel = TRUE, legend.title = "Pays") +
  labs(title = "ACP — Biplot (individus + variables)") + theme_geo

save_plot("17_biplot_acp.png", p10g, width = 10, height = 8)


# ════════════════════════════════════════════════════════════
#  MODULE 11 : K-MEANS (sur les features ACP)
# ════════════════════════════════════════════════════════════

cat("── Module 11 : K-means ─────────────────────────────────\n")

# ----------------------------------------------------------
# 1. Préparation des données
# ----------------------------------------------------------

df_km_clean <- df_pca %>%
  select(all_of(FEATURES_NUM)) %>%
  
  # garder seulement les variables numériques
  select(where(is.numeric)) %>%
  
  # remplacer Inf par NA
  mutate(across(everything(),
                ~ replace(., is.infinite(.), NA))) %>%
  
  # supprimer colonnes totalement NA
  select(where(~ sum(is.na(.)) < length(.))) %>%
  
  # supprimer lignes contenant NA
  na.omit() %>%
  
  # supprimer variables constantes
  select(where(~ sd(.) > 0))

# Standardisation
df_km_scaled <- scale(df_km_clean)

# Vérification
cat("NA restants :", sum(is.na(df_km_scaled)), "\n")
cat("NaN restants :", sum(is.nan(df_km_scaled)), "\n")
cat("Inf restants :", sum(is.infinite(df_km_scaled)), "\n")

# ----------------------------------------------------------
# 2. Choix du nombre optimal de clusters
# ----------------------------------------------------------

# Méthode du coude
p11a <- fviz_nbclust(
  df_km_scaled,
  kmeans,
  method = "wss",
  k.max = 10
) +
  geom_vline(xintercept = 3,
             linetype = "dashed",
             color = "#E24B4A") +
  labs(
    title = "Méthode du coude",
    x = "Nombre de clusters K",
    y = "WSS"
  ) +
  theme_geo

# Méthode silhouette
p11b <- fviz_nbclust(
  df_km_scaled,
  kmeans,
  method = "silhouette",
  k.max = 10
) +
  labs(
    title = "Méthode de silhouette",
    x = "Nombre de clusters K",
    y = "Score silhouette"
  ) +
  theme_geo

save_plot("18_choix_kmeans.png",
          p11a | p11b,
          width = 14,
          height = 5)

# ----------------------------------------------------------
# 3. K-means final
# ----------------------------------------------------------

set.seed(42)

km3 <- kmeans(
  df_km_scaled,
  centers = 3,
  nstart = 25,
  iter.max = 100
)

# Ajout des clusters
df_km_clean$cluster_km <- factor(
  km3$cluster,
  labels = c("Cluster 1", "Cluster 2", "Cluster 3")
)

cat("\nTaille des clusters :\n")
print(table(df_km_clean$cluster_km))

# ----------------------------------------------------------
# 4. Visualisation des clusters
# ----------------------------------------------------------

p11c <- fviz_cluster(
  km3,
  data = df_km_scaled,
  geom = "point",
  ellipse.type = "convex",
  palette = c("#2E86AB", "#F6C85F", "#D64550"),
  ggtheme = theme_geo
) +
  labs(title = "Visualisation K-means")

save_plot("19_clusters_kmeans.png",
          p11c,
          width = 9,
          height = 7)

# ----------------------------------------------------------
# 5. Profils des clusters
# ----------------------------------------------------------

vars_profile <- c(
  "Military_Expenditure_Billion_USD",
  "Inflation_Rate_Percent",
  "Brent_Oil_Price_USD_per_barrel",
  "Conflict_Severity_Index"
)

vars_profile <- vars_profile[
  vars_profile %in% names(df_km_clean)
]

p11d <- df_km_clean %>%
  select(cluster_km, all_of(vars_profile)) %>%
  pivot_longer(
    cols = -cluster_km,
    names_to = "variable",
    values_to = "valeur"
  ) %>%
  ggplot(aes(cluster_km,
             valeur,
             fill = cluster_km)) +
  
  geom_boxplot(
    show.legend = FALSE,
    outlier.size = 1
  ) +
  
  facet_wrap(
    ~variable,
    scales = "free"
  ) +
  
  scale_fill_manual(values = c(
    "Cluster 1" = "#D9F0FF",
    "Cluster 2" = "#FFE7B3",
    "Cluster 3" = "#FFD6D6"
  )) +
  
  labs(
    title = "Profils économiques et géopolitiques des clusters",
    x = NULL,
    y = NULL
  ) +
  
  theme_geo +
  theme(
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    )
  )

save_plot("20_profils_clusters.png",
          p11d,
          width = 11,
          height = 7)

# ----------------------------------------------------------
# 6. Centres des clusters
# ----------------------------------------------------------

cat("\nCentres standardisés des clusters :\n")
print(round(km3$centers, 2))

# ----------------------------------------------------------
# 7. Score silhouette final
# ----------------------------------------------------------

sil <- cluster::silhouette(
  km3$cluster,
  dist(df_km_scaled)
)

score_sil <- mean(sil[, 3])

cat("\nScore silhouette final :",
    round(score_sil, 4),
    "\n")
# ════════════════════════════════════════════════════════════
#  MODULE 12 : CAH (Classification Ascendante Hiérarchique)
# ════════════════════════════════════════════════════════════
cat("── Module 12 : CAH ─────────────────────────────────────\n")

dist_matrix <- dist(df_km_scaled, method = "euclidean")
cah_result  <- hclust(dist_matrix, method = "ward.D2")

# Dendrogramme
png(file.path(PATH_OUTPUT, "21_dendrogramme.png"), width = 1400, height = 700, res = 130)
plot(cah_result, labels = FALSE, hang = -1,
     main = "CAH — Dendrogramme (méthode de Ward)",
     xlab = "Observations", ylab = "Hauteur (distance de Ward)")
rect.hclust(cah_result, k = 3, border = c("#1D9E75", "#BA7517", "#E24B4A"))
dev.off()
cat("  → 21_dendrogramme.png sauvegardé\n")

# Groupes CAH
clusters_cah    <- cutree(cah_result, k = 3)
df_pca$cluster_cah <- factor(clusters_cah,
                             labels = c("Groupe A", "Groupe B", "Groupe C"))

cat("CAH — Taille des groupes :\n"); print(table(df_pca$cluster_cah))
cat("\nCAH vs Périodes réelles :\n")
print(table(df_pca$cluster_cah, df_pca$periode))

p12 <- fviz_cluster(list(data = df_km_scaled, cluster = clusters_cah),
                    palette = c("#1D9E75", "#BA7517", "#E24B4A"),
                    geom = "point", ellipse.type = "convex",
                    ggtheme = theme_geo) +
  labs(title = "CAH (K=3) — Groupes visualisés sur ACP")

save_plot("22_cah_sur_acp.png", p12, width = 9, height = 7)


