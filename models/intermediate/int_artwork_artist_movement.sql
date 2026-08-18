-- Intermediate: artwork_artist_movement
-- Bir sanatçının birden fazla akımı olabildiği için (örn. Picasso:
-- Cubism + Surrealism + Post-Impressionism), bu köprü tablo ana
-- artwork_artist_detail'e karıştırılmadı — akım bazlı analiz (H3)
-- için ayrı tutuldu. Sadece Wiki_QID eşleşmesi olan sanatçıları
-- (analiz edilebilir alt küme, ~3.224 kişi) içerir.
--
-- Kaynak sorgu: bigquery_sorgulari.md, bölüm 11

{{ config(materialized='table') }}

select
    d.object_id,
    d.constituent_id,
    d.display_name,
    d.gender_kategori,
    d.ulke_bolge,
    w.movement,
    w.wikidata_birthplace,
    w.wikidata_citizenship

from {{ ref('int_artwork_artist_detail') }} d
join {{ ref('stg_wikidata_enrichment') }} w
    on d.wiki_qid = w.artist_qid
