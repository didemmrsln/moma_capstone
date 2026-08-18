-- Staging: wikidata_enrichment
-- Değişiklik yok, sadece isim standardizasyonu.
-- Bir sanatçının birden fazla akımı olabildiği için bu tablo
-- doğası gereği bire-çok (aynı artist_qid birden fazla satırda).

select
    artist_qid,
    movement,
    birthplace as wikidata_birthplace,
    citizenship as wikidata_citizenship

from {{ source('moma_raw', 'wikidata_enrichment') }}
