# Does MoMA Set the Trend, or Follow It?
### A Data Study of MoMA's Acquisition Patterns

This project investigates institutional bias in museum acquisition
behavior using MoMA's public collection dataset. The core metric is
**acquisition lag** — the gap between an artwork's creation year and
the year MoMA added it to the collection — examined across gender,
geography, art movement, and time.

## The Question

A museum can't collect everything. Every acquisition is a choice —
who gets recognized, and when. This project traces that choice across
four hypotheses:

- **H1 — Gender:** Does acquisition lag differ between female and
  male artists, and is that difference real or a chronological
  illusion?
- **H2 — Geography:** Is the gap between Western and non-Western
  artists permanent or temporary?
- **H3 — Movement:** Which art movements did MoMA recognize early,
  and which did it recognize late — and did that pattern change over
  time?
- **H4 — Temporal Consistency:** Is MoMA's acquisition behavior
  predictable, or random?

## Data

- **MoMA Collection Dataset** (CC0) — 160,699 artworks, 15,932 artists
  — [github.com/MuseumofModernArt/collection](https://github.com/MuseumofModernArt/collection)
- **Wikidata** (SPARQL, CC0) — movement and geography enrichment for
  3,224 artists

## Architecture

Built on a layered dbt + BigQuery pipeline:

```
staging      → source cleaning (date parsing, category normalization)
intermediate → artwork–artist–movement relationship tables
marts        → analysis-ready tables (mart_acquisition_lag,
               mart_gender_analysis, mart_geography_analysis,
               mart_movement_analysis)
```

Statistical testing (Mann-Whitney U, Pearson correlation,
autocorrelation) and machine learning (compound-growth projections,
log-linear regression) were done in Python (pandas, numpy,
scikit-learn) via Google Colab.

## Key Findings

| Hypothesis | Result |
|---|---|
| H1 · Gender | Lag gap closed statistically by 1990–2010 (p=0.418) — but artwork-count parity is still ~80 years away |
| H2 · Geography | Gap narrowed but never lost statistical significance (p<0.001 in every period) — a persistent pattern |
| H3 · Movement | MoMA's focus reversed over time: early on its own contemporaries, now catching up on previously overlooked movements |
| H4 · Consistency | MoMA's behavior is strongly predictable, not random (r=0.855) |

A supplementary model estimates "lost potential" for artists who died
young, using first-8-year output to predict full-career productivity
(R²=0.705).

## Repository Structure

```
models/                           dbt models (staging, intermediate, marts)
MoMA_Collection_Analysis.ipynb    polished, narrative analysis notebook
MoMA_DATA.ipynb                   full working notebook (EDA → stats → ML)
MoMA_Capstone_Report_EN.pdf       full methodology report
MoMA_Capstone_Presentation_EN.pdf slide deck
```

## Deliverables

- 📊 [Interactive Dashboard](https://datastudio.google.com/reporting/a1599e07-6755-49e3-8e67-4b60500d3114) — Looker Studio
- 📄 [Report (PDF)](./MoMA_Capstone_Report_EN.pdf)
- 🎞️ [Presentation (PDF)](./MoMA_Capstone_Presentation_EN.pdf)
- 🎬 [Video Summary](https://drive.google.com/file/d/1ajOTI4usEU5237Vu3-4RtvExgalb5sj_/view?usp=sharing) — NotebookLM narrative overview

## Author

**Didem Arslan Yenihayat** — Workintech Data Science Bootcamp, Capstone Project
