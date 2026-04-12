#chargement des packages 
library(tidyverse)
library(ggrepel)
library(scales)
library(patchwork)
library(viridis)

# ÉTAPE 1 — CHARGEMENT
d_conflict <- read_csv("C:/Users/arijk/Downloads/war_history_economics_1948_2026.csv")
d_eco <- read_csv("C:/Users/arijk/Downloads/Middle_East_Economic_Data_1990_2024_with_Oil.csv")

# Vérification
cat("Pays conflict :", unique(d_conflict$Country), "\n")
cat("Pays eco      :", unique(d_eco$Country), "\n")

# ÉTAPE 2 — PRÉPARATION DES SOUS-DATASETS

PAYS <- c("USA", "Israel", "Iran")

# conf3 : base principale — 1948 à 2024 → 3 × 77 = 231 lignes
conf3 <- d_conflict %>%
  filter(Country %in% PAYS) %>%
  rename(country = Country, year = Year) %>%
  filter(year >= 1948, year <= 2024)

# eco3 : données économiques — 1990 à 2024 (seulement les 3 pays)
eco3 <- d_eco %>%
  filter(Country %in% PAYS) %>%
  rename(country = Country, year = Year) %>%
  select(-Country_Code)

# Vérification des dimensions avant fusion
cat("\nconf3 :", nrow(conf3), "lignes\n")
cat("eco3  :", nrow(eco3),  "lignes\n")
conf3 %>% count(country) %>% print()
eco3  %>% count(country) %>% print()


# ÉTAPE 3 — FUSION (conf3 comme base)


df <- conf3 %>%
  left_join(eco3, by = c("country", "year")) %>%
  mutate(
    periode = case_when(
      is.na(Conflict_Severity_Index) ~ "Paix",
      Conflict_Severity_Index == 0   ~ "Paix",
      Conflict_Severity_Index <= 4   ~ "Conflit modéré",
      TRUE                           ~ "Conflit intense"
    ),
    periode = factor(periode,
                     levels = c("Paix", "Conflit modéré", "Conflit intense"))
  )

# ── Vérification finale ──────────────────────
cat("\n=== DATASET FINAL ===\n")
cat("Dimensions :", dim(df), "\n")
cat("\nLignes par pays :\n")
df %>% count(country) %>% print()
cat("\nPériode couverte par pays :\n")
df %>%
  group_by(country) %>%
  summarise(de = min(year), a = max(year), n = n()) %>%
  print()
cat("\nValeurs manquantes par colonne :\n")
colSums(is.na(df)) %>% sort(decreasing = TRUE) %>% print()
glimpse(df)

# ÉTAPE 4 — CONFLITS → PRIX DU PÉTROLE (BRENT)


# Corrélation (période avec données Brent = après 1990)
cor_brent <- df %>%
  filter(!is.na(Brent_Oil_Price_USD_per_barrel)) %>%
  group_by(country) %>%
  summarise(
    r = cor(Conflict_Severity_Index,
            Brent_Oil_Price_USD_per_barrel,
            use = "complete.obs"),
    n = n(),
    .groups = "drop"
  )
cat("\nCorrélation Severity × Brent :\n")
print(cor_brent)

# Timeline Brent + Sévérité
brent_base <- df %>%
  filter(country == "USA") %>%
  select(year, Brent_Oil_Price_USD_per_barrel,
         Conflict_Severity_Index, Significant_Event) %>%
  distinct()

events_annot <- brent_base %>%
  filter(!is.na(Significant_Event),
         !is.na(Brent_Oil_Price_USD_per_barrel)) %>%
  slice_max(Brent_Oil_Price_USD_per_barrel, n = 8)

p_brent <- ggplot(brent_base, aes(x = year)) +
  geom_col(aes(y = Conflict_Severity_Index * 10),
           fill = "#185FA5", alpha = 0.4, width = 0.7) +
  geom_area(aes(y = Brent_Oil_Price_USD_per_barrel),
            fill = "#E8593C", alpha = 0.2, na.rm = TRUE) +
  geom_line(aes(y = Brent_Oil_Price_USD_per_barrel),
            color = "#E8593C", linewidth = 1.1, na.rm = TRUE) +
  geom_text_repel(
    data         = events_annot,
    aes(y        = Brent_Oil_Price_USD_per_barrel,
        label    = Significant_Event),
    size         = 2.6,
    color        = "#333333",
    nudge_y      = 8,
    segment.size = 0.3,
    max.overlaps = 10
  ) +
  scale_y_continuous(
    name     = "Brent (USD/baril)",
    sec.axis = sec_axis(~ . / 10, name = "Conflict Severity Index")
  ) +
  scale_x_continuous(breaks = seq(1948, 2024, 10)) +
  labs(
    title    = "Prix du Brent vs Sévérité des conflits (1948–2024)",
    subtitle = "Barres bleues = Severity Index | Aire rouge = Brent (dispo depuis 1990)",
    x        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

print(p_brent)


# ÉTAPE 5 — CONFLITS → INFLATION


# Résumé statistique
inf_summary <- df %>%
  group_by(country, periode) %>%
  summarise(
    moy_inf = mean(Inflation_Rate_Percent, na.rm = TRUE),
    sd_inf  = sd(Inflation_Rate_Percent,   na.rm = TRUE),
    n       = n(),
    .groups = "drop"
  )
cat("\nInflation moyenne par pays et période :\n")
print(inf_summary)

p_inflation <- ggplot(df,
                      aes(x = year,
                          y = Inflation_Rate_Percent,
                          color = country)) +
  geom_line(linewidth = 0.9, na.rm = TRUE) +
  geom_point(aes(shape = periode), size = 1.8,
             alpha = 0.85, na.rm = TRUE) +
  facet_wrap(~ country, scales = "free_y", ncol = 1) +
  scale_color_manual(values = c("USA"    = "#185FA5",
                                "Israel" = "#3B6D11",
                                "Iran"   = "#D85A30")) +
  scale_x_continuous(breaks = seq(1948, 2024, 10)) +
  labs(
    title    = "Inflation annuelle par pays (1948–2024)",
    subtitle = "Forme des points = intensité du conflit",
    x        = NULL,
    y        = "Inflation (%)",
    color    = "Pays",
    shape    = "Période"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title      = element_text(face = "bold"))

print(p_inflation)


# ÉTAPE 6 — PERTES ÉCONOMIQUES


# Zones de conflits intenses pour annotation
zones_conflit <- df %>%
  filter(Conflict_Severity_Index >= 5) %>%
  select(year) %>%
  distinct()

# PIB & dépenses militaires
p_eco <- df %>%
  select(country, year,
         GDP_growth_annual_pct,
         Military_Expenditure_Billion_USD) %>%
  pivot_longer(
    cols      = c(GDP_growth_annual_pct,
                  Military_Expenditure_Billion_USD),
    names_to  = "indicateur",
    values_to = "valeur"
  ) %>%
  mutate(indicateur = recode(indicateur,
                             "GDP_growth_annual_pct"            = "Croissance PIB (%)",
                             "Military_Expenditure_Billion_USD" = "Dépenses militaires (Mrd $)"
  )) %>%
  ggplot(aes(x = year, y = valeur, color = country)) +
  geom_rect(
    data        = zones_conflit,
    aes(xmin    = year - 0.5, xmax = year + 0.5,
        ymin    = -Inf, ymax = Inf),
    inherit.aes = FALSE,
    fill        = "#E24B4A",
    alpha       = 0.07
  ) +
  geom_line(linewidth = 0.9, na.rm = TRUE) +
  facet_grid(indicateur ~ country, scales = "free_y") +
  scale_color_manual(values = c("USA"    = "#185FA5",
                                "Israel" = "#3B6D11",
                                "Iran"   = "#D85A30")) +
  scale_x_continuous(breaks = seq(1948, 2024, 15)) +
  labs(
    title = "PIB & dépenses militaires (zones rouges = Severity ≥ 5)",
    x     = NULL,
    y     = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "none",
        plot.title      = element_text(face = "bold"))

print(p_eco)

# Personnel actif
p_personnel <- ggplot(df,
                      aes(x     = year,
                          y     = Active_Personnel / 1e6,
                          color = country,
                          fill  = country)) +
  geom_area(alpha = 0.2, position = "identity", na.rm = TRUE) +
  geom_line(linewidth = 1, na.rm = TRUE) +
  scale_color_manual(values = c("USA"    = "#185FA5",
                                "Israel" = "#3B6D11",
                                "Iran"   = "#D85A30")) +
  scale_fill_manual(values  = c("USA"    = "#185FA5",
                                "Israel" = "#3B6D11",
                                "Iran"   = "#D85A30")) +
  scale_y_continuous(labels = label_number(suffix = "M")) +
  scale_x_continuous(breaks = seq(1948, 2024, 10)) +
  labs(
    title = "Personnel militaire actif (1948–2024)",
    x     = NULL,
    y     = "Millions de soldats",
    color = NULL,
    fill  = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title      = element_text(face = "bold"))

print(p_personnel)


# ÉTAPE 7 — COMPARAISON DES 3 PAYS


# Heatmap sévérité + inflation
p_heatmap <- ggplot(df,
                    aes(x    = year,
                        y    = country,
                        fill = Conflict_Severity_Index)) +
  geom_tile(color = "white", linewidth = 0.25) +
  geom_text(
    aes(label = ifelse(!is.na(Inflation_Rate_Percent),
                       round(Inflation_Rate_Percent, 0), "")),
    size  = 1.8,
    color = "white"
  ) +
  scale_fill_viridis(option    = "inferno",
                     direction = -1,
                     name      = "Sévérité",
                     na.value  = "grey90") +
  scale_x_continuous(breaks = seq(1948, 2024, 10)) +
  labs(
    title = "Heatmap : Sévérité (couleur) & Inflation (chiffres, 1948–2024)",
    x     = NULL,
    y     = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title  = element_text(face = "bold"),
        axis.text.y = element_text(face = "bold"))

print(p_heatmap)

# Scatter sévérité × croissance PIB
df_scatter <- df %>%
  filter(!is.na(Conflict_Severity_Index),
         !is.na(GDP_Growth_Percent))

p_scatter <- ggplot(df_scatter,
                    aes(x     = Conflict_Severity_Index,
                        y     = GDP_Growth_Percent,
                        color = country)) +
  geom_hline(yintercept = 0, linetype = "dashed",
             color = "grey60", linewidth = 0.5) +
  geom_smooth(method    = "lm",
              se        = TRUE,
              linewidth = 0.8,
              linetype  = "dashed",
              alpha     = 0.12) +
  geom_point(aes(size = Military_Expenditure_Billion_USD),
             alpha = 0.7) +
  geom_text_repel(aes(label = year),
                  size         = 2.3,
                  max.overlaps = 6) +
  scale_color_manual(values = c("USA"    = "#185FA5",
                                "Israel" = "#3B6D11",
                                "Iran"   = "#D85A30")) +
  scale_size_continuous(range = c(2, 9),
                        name  = "Dép. mil.\n(Mrd $)") +
  labs(
    title    = "Sévérité du conflit vs Croissance du PIB (1948–2024)",
    subtitle = "Taille des points = dépenses militaires",
    x        = "Conflict Severity Index (0–10)",
    y        = "Croissance PIB (%)",
    color    = "Pays"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "right",
        plot.title      = element_text(face = "bold"))

print(p_scatter)

# ÉTAPE 8 — DASHBOARD FINAL → PNG direct


p_bar_mil <- df %>%
  filter(!is.na(Military_Expenditure_Billion_USD)) %>%
  ggplot(aes(x    = year,
             y    = Military_Expenditure_Billion_USD,
             fill = country)) +
  geom_col(position = "dodge", width = 0.7, alpha = 0.85) +
  scale_fill_manual(values = c("USA"    = "#185FA5",
                               "Israel" = "#3B6D11",
                               "Iran"   = "#D85A30")) +
  scale_x_continuous(breaks = seq(1948, 2024, 10)) +
  scale_y_continuous(labels = label_dollar(suffix = "B")) +
  labs(
    title = "Dépenses militaires (Mrd $, 1948–2024)",
    x     = NULL,
    y     = NULL,
    fill  = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom",
        plot.title      = element_text(face = "bold", size = 10))

# Sauvegarde directe en PNG (évite l'erreur RStudio plot window)
png(filename = "C:/Users/arijk/Downloads/dashboard_geopolitique.png",
    width    = 2600,
    height   = 1600,
    res      = 150)

dashboard <- (p_brent / p_heatmap) | (p_scatter / p_bar_mil)

print(
  dashboard + plot_annotation(
    title    = "Analyse géopolitique — USA · Israël · Iran (1948–2024)",
    subtitle = paste("Dataset final :", nrow(df), "observations ·",
                     n_distinct(df$country), "pays ·",
                     n_distinct(df$year), "années"),
    caption  = "Sources : war_history_economics + Middle_East_Economic_Data",
    theme    = theme(
      plot.title    = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(size = 11, color = "grey40")
    )
  )
)

dev.off()

cat("\nDashboard sauvegardé :\n")
cat("C:/Users/arijk/Downloads/dashboard_geopolitique.png\n")
cat("\nDataset final : ", nrow(df), "observations\n")
write.csv(df, "C:/Users/arijk/Downloads/data.csv", row.names = FALSE)

