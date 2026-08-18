-- Mart: geography_analysis
-- H2 hipotezi: batı-dışı sanatçılarda koleksiyona giriş süresi
-- farklı mı? Fark zamanla daralıyor mu?

{{ config(materialized='table') }}

select
    d.object_id,
    d.constituent_id,
    d.display_name,
    d.ulke_bolge,
    d.gender_kategori,
    l.extracted_year,
    l.acquired_year,
    l.acquisition_lag,
    cast(floor(l.extracted_year / 10) * 10 as int64) as yapim_on_yili

from {{ ref('int_artwork_artist_detail') }} d
join {{ ref('mart_acquisition_lag') }} l
    on d.object_id = l.object_id

where d.is_analyzable = true
    and l.lag_hesaplanabilirlik = 'hesaplanabilir'
