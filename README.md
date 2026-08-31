# Does MoMA Set the Trend, or Follow It?

Quantifying 90 years of acquisition behaviour at the Museum of Modern Art.

**Didem Arslan** — Data Analytics Capstone

A museum's collection is not a neutral archive. Every acquisition is a decision about what
counts as art worth keeping, and *when* that decision gets made says something the collection
itself does not: how long an artist had to wait for institutional recognition.

The project defines one metric — the **acquisition lag** — and asks whether that wait has
been distributed evenly:

```
acquisition lag = year the work entered MoMA − year the work was made
```

Full analysis: [`MoMA_Collection_Analysis.ipynb`](MoMA_Collection_Analysis.ipynb)
(outputs preserved, readable without running it).

## Hypotheses and verdicts

| | Hypothesis | Verdict |
|---|---|---|
| **H1** | Works by women artists were acquired more slowly | **Confirmed, then closed.** A 28-year median gap in 1950–70 shrinks to zero by 1990–2010 (*p* = 0.418) |
| **H2** | Works by non-Western artists were acquired more slowly | **Confirmed, and still open.** Non-Western median lag stays 2–3× Western in every period (*p* < 0.001 throughout) |
| **H3** | Some art movements were recognised earlier than others | **Confirmed, with a reversal.** MoMA front-ran movements it collected heavily before 1970 (*r* = −0.64), then inverted after 2000 (*r* = +0.73) |
| **H4** | Acquisition behaviour is temporally consistent | **Confirmed.** Lag-1 autocorrelation *r* = 0.855, *p* = 0.0016 |

**The headline finding is the contrast between H1 and H2.** The gender gap in acquisition
*speed* closed completely; the geographic gap, measured identically over the same seventy
years, never did. MoMA has demonstrated it can change this behaviour — which makes the
persistence of the geographic gap a question of what got prioritised, not of what was possible.

Numerical representation remains skewed in both dimensions — roughly 6:1 male (123,378 vs
21,828 works) and 7:1 Western (127,205 vs 18,969) as of 2020 — with trend extrapolation
putting parity near the end of this century.

**Answering the title question: both, in sequence.** In its founding decades MoMA behaved like
a trend-setter, collecting most heavily where it had moved first. Since 2000 it has behaved
like a follower and a corrector — buying into movements it once passed over, while the average
work it acquires is older each decade.

### Supplementary model — artists who died young

A separate question on the same data: can early-career output predict an artist's eventual
presence in the collection? A log-transformed linear fit — `log(total + 1) = 1.057 ×
log(early_8yr + 1) + 0.182`, held-out **R² = 0.705**, n = 5,656 — is applied to 187 artists
whose careers ran under 40 years to estimate the work a normal lifespan might have produced.
Out-of-sample checks: Keith Haring (actual 49, predicted 48.8), Basquiat (actual 12, predicted
17). This is the most speculative part of the project and is presented as such.

### The confounder worth flagging

The first, uncontrolled cut of the gender data showed women being acquired **faster** than men
(mean 22.7 years vs 29.1). That result is an artefact: works by women in this collection are on
average 23 years more recent (mean creation year 1978 vs 1955). Once creation year is held
fixed, the direction inverts and the real gap appears. Section 7 of the notebook walks through
how it was caught, because catching it is the analysis.

## Data sources

| Source | Rows | What it provides | Licence |
|---|---|---|---|
| [MoMA `Artworks.csv`](https://github.com/MuseumofModernArt/collection) | 160,699 | Title, artist, creation date, acquisition date, medium, department | CC0 |
| [MoMA `Artists.csv`](https://github.com/MuseumofModernArt/collection) | ~15,000 | Name, nationality, gender, birth/death year, Wikidata QID | CC0 |
| [Wikidata SPARQL](https://query.wikidata.org/) | 3,224 artists | Art movement (P135), birthplace (P19), citizenship (P27) | CC0 |
| Nationality → region map | 128 values | Hand-built lookup from free-text nationality to country/region | Authored for this project |

## Architecture

```
MoMA CSVs ─┐
Wikidata  ─┼─►  BigQuery  ──►  dbt  ──────────────────►  BigQuery  ──►  Python
Region map ┘    moma_raw       staging → intermediate     moma_dbt      analysis
                (4 tables)     → marts (7 models)         (marts)       + ML
                                                                          │
                                                          moma_dashboard ◄┘
                                                          (BI serving layer)
```

Each layer has one job. `moma_raw` holds untouched source data. **dbt** does the joins, the
category consolidation and the metric definition — version-controlled, testable SQL rather
than notebook cells. `moma_dbt` marts are analysis-ready. `moma_dashboard` is the serving
layer the BI dashboard reads from.

**Stack:** Python (pandas, numpy, matplotlib, seaborn, scipy, scikit-learn) · SQL · dbt ·
BigQuery · Wikidata SPARQL

### Method: information is flagged, never deleted

Every cleaning step marks ambiguous records instead of dropping them. Free-text dates that
cannot be parsed get `year_confidence = 'no_year'` rather than disappearing; institution rows
get `is_analyzable = false` rather than being filtered out upstream. The analysable subset
stays visible as a *fraction of the whole*, so any reader can see what a given number is
computed over.

### Statistics

The lag distribution is strongly right-skewed (mean 29 years against a median of 21), so the
median is reported throughout and two-group comparisons use the non-parametric **Mann-Whitney
U** test rather than a *t*-test. Correlations use Pearson's *r*. Group comparisons are run
inside fixed creation-year windows (1950–70, 1970–90, 1990–2010) so creation year cannot drive
the difference. A robustness pass re-runs H1 with the 1964 and 1968 mass donations excluded —
two near-homogeneous bequests (98–99% male, 97–99% Western) that dominate the raw acquisition
histogram — and the finding survives.

## Repository layout

```
MoMA_Collection_Analysis.ipynb   Full analysis: ingestion → dbt → statistics → modelling
models/staging/                  Source renaming, is_analyzable flag           (4 models + sources.yml)
models/intermediate/             Multi-artist unnesting, gender consolidation  (3 models)
models/marts/                    acquisition_lag, gender, geography, movement  (4 models)
sql/                             BigQuery query archive
sparql/                          Wikidata SPARQL query documentation
macros/ seeds/ snapshots/ tests/ dbt project scaffolding
dbt_project.yml                  dbt configuration
```

## Reproducibility

**The notebook cannot be re-run end to end by a third party.** Everything from Section 4
onwards reads from `moma-capstone`, a private BigQuery project; the rendered outputs are
preserved from the original run so the analysis is fully readable without access.

Independently reproducible:

- **Sections 1–3** (raw ingestion, date parsing, Wikidata enrichment) run against public
  sources only — no credentials needed.
- **All SQL and dbt logic** is printed inline in the notebook and mirrored in `models/`.
- **Every statistic quoted in the narrative** is computed in a visible cell.

Running the full pipeline requires a GCP project with BigQuery enabled, a dbt profile pointing
at it, and the nationality → region CSV.

## Limitations

- **Movement coverage.** Wikidata supplies movement data for 43.4% of the collection, and
  coverage is not random — H3 describes the well-documented portion, not all of it.
- **Date parsing.** `extracted_year` takes the first 4-digit year in a free-text field; 95
  works (0.06%) produce negative lags and are flagged rather than deleted.
- **The West / non-West binary** is a blunt simplification of a contested concept, defined
  explicitly in Section 8.1 and fit for the institutional question asked here.
- **Gender categories.** 428 raw values consolidated to 5; the male/female comparison excludes
  categories too small for the tests used.
- **Acquisition ≠ recognition.** The metric captures institutional behaviour, not artistic
  reputation.
- **Projections are extrapolations** that assume current trends continue; ranges are given
  instead of point estimates wherever the underlying growth rate is unstable.
- **Donation-driven composition.** Much of the collection arrived by bequest, so some of what
  reads as curatorial choice is the shape of what was offered.

## Further work

- Layer in exhibition data — acquisition and display are different forms of recognition
- Compare against a peer institution (the Met's open data is already structured for this)
- Model the acquisition-lag distribution directly (survival analysis fits the shape better)
- Replace the West/non-West binary with a finer regional breakdown

---

*Data: [MoMA Collection](https://github.com/MuseumofModernArt/collection) (CC0) ·
[Wikidata](https://www.wikidata.org) (CC0).*

*Workintech Data Science & Analytics Bootcamp — Capstone Project, 2026*
