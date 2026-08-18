-- Mart: movement_analysis
-- H3 hipotezi: hangi akım hızla, hangisi gecikmeyle kabul görmüş?

{{ config(materialized='table') }}

select
    m.object_id,
    m.constituent_id,
    m.display_name,
    m.movement,
    m.gender_kategori,
    m.ulke_bolge,
    l.extracted_year,
    l.acquired_year,
    l.acquisition_lag,
    cast(floor(l.extracted_year / 10) * 10 as int64) as yapim_on_yili

from {{ ref('int_artwork_artist_movement') }} m
join {{ ref('mart_acquisition_lag') }} l
    on m.object_id = l.object_id

where l.lag_hesaplanabilirlik = 'hesaplanabilir'
    and m.movement is not null
