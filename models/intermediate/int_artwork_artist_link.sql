-- Intermediate: artwork_artist_link
-- Çoklu sanatçılı eserlerde ConstituentID virgülle ayrılmış halde
-- tutuluyor (örn. "26171, 9216"). Bu model her sanatçıyı ayrı bir
-- satıra açıyor (SPLIT + UNNEST), TRIM ile join uyumluluğu için
-- boşluk temizliği yapıyor.
--
-- Kaynak sorgu: bigquery_sorgulari.md, bölüm 9

{{ config(materialized='table') }}

select
    object_id,
    trim(single_constituent_id) as constituent_id

from {{ ref('stg_artworks') }},
unnest(split(constituent_id_raw, ',')) as single_constituent_id

where constituent_id_raw is not null and constituent_id_raw != ''
