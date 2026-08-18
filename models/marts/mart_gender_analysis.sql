-- Mart: gender_analysis
-- H1 hipotezi: kadın sanatçıların eserleri ortalama daha mı geç
-- alınmış? Fark on yıllara göre kapanıyor mu?

{{ config(materialized='table') }}

select
    d.object_id,
    d.constituent_id,
    d.display_name,
    d.gender_kategori,
    d.ulke_bolge,
    l.extracted_year,
    l.acquired_year,
    l.acquisition_lag,
    cast(floor(l.extracted_year / 10) * 10 as int64) as yapim_on_yili

from {{ ref('int_artwork_artist_detail') }} d
join {{ ref('mart_acquisition_lag') }} l
    on d.object_id = l.object_id

where d.is_analyzable = true
    and l.lag_hesaplanabilirlik = 'hesaplanabilir'
