-- Mart: acquisition_lag
-- Ana analiz metriği: edinim gecikmesi = DateAcquired yılı -
-- eserin yapıldığı yıl (extracted_year).
--
-- Bu model Artworks'ün TAM 160.699 satırı üzerinden çalışıyor —
-- Wikidata kısıtına bağlı değil (geniş katman / Katman A analizi).
--
-- 95 satırda negatif gecikme görüldü (%0.06) — muhtemelen Date
-- sütunundaki karma format satırlarında (örn. "1930 (printed 1944)")
-- yıl-çıkarma fonksiyonunun basım yılını orijinal yerine yakalaması.
-- Silinmedi, ayrı kategori olarak işaretlendi (bkz. bigquery_
-- sorgulari.md, mart bölümü).

{{ config(materialized='table') }}

select
    object_id,
    title,
    artist_raw,
    date_raw,
    extracted_year,
    year_confidence,
    has_production_note,
    date_acquired_raw,
    extract(year from safe_cast(date_acquired_raw as date)) as acquired_year,
    case
        when extracted_year is not null
            and safe_cast(date_acquired_raw as date) is not null
        then extract(year from safe_cast(date_acquired_raw as date)) - extracted_year
        else null
    end as acquisition_lag,
    case
        when extracted_year is null then 'yil_cikarilamadi'
        when safe_cast(date_acquired_raw as date) is null then 'edinim_tarihi_yok'
        when extract(year from safe_cast(date_acquired_raw as date)) - extracted_year < 0
            then 'mantiksiz_negatif'
        else 'hesaplanabilir'
    end as lag_hesaplanabilirlik,
    medium,
    classification,
    department

from {{ ref('stg_artworks') }}
