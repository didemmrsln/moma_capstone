# The Recognition Lag — Who Gets Recognized, and When?

Data analysis of MoMA's acquisition behavior: does the museum recognize
artists and movements at different speeds depending on gender, geography,
or artistic movement — and is that pattern real or a statistical illusion?

**Metric:** *Acquisition lag* = year acquired − year the work was produced.

## Data
- MoMA Collection Dataset (CC0) — 160,699 artworks, 15,932 artists
  ([source](https://github.com/MuseumofModernArt/collection))
- Wikidata SPARQL enrichment — movement & geography for 3,224 artists

## Method
- **Warehouse:** BigQuery, layered dbt architecture (staging → intermediate → marts)
- **Analysis:** Python (pandas, numpy, scikit-learn, matplotlib, seaborn) in Colab
- **Statistics:** Mann-Whitney U, Pearson correlation, lag-1 autocorrelation,
  confound control via period-stratified comparison
- **Modeling:** log-transformed regression estimating early-career productivity
  as a predictor of lifetime output (R²=0.705, n=5,656)

## Key findings
- Gender-based acquisition lag has closed statistically (p=0.418, 1990–2010)
- Geography-based lag has narrowed but remains significant in every period (p<0.001)
- MoMA's institutional focus reversed over time: early acquisitions favored
  contemporaries; post-2000 acquisitions compensate for previously
  under-collected movements
- The institution's acquisition pace shows strong period-to-period consistency
  (r=0.855)

## Full write-up
Full methodology, limitations, and statistical detail are in the accompanying
report and presentation slides (see repository root / `analyses` folder).

---
*Workintech Data Science & Analytics Bootcamp — Capstone Project, 2026*
