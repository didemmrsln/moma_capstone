-- Staging: artists
-- ArtistBio dolu olan kayıtlar "analiz edilebilir" kabul edildi
-- (bkz. bigquery_sorgulari.md, bölüm 6) — kurum/stüdyo satırlarının
-- büyük kısmı burada elenmiş oluyor. is_analyzable bayrağı bilgi
-- kaybı olmadan saklanıyor, silme yapılmıyor.

select
    ConstituentID as constituent_id,
    DisplayName as display_name,
    ArtistBio as artist_bio,
    Nationality as nationality_raw,
    Gender as gender_raw,
    BeginDate as begin_date,
    EndDate as end_date,
    Wiki_QID as wiki_qid,
    ULAN as ulan,
    case
        when ArtistBio is not null and ArtistBio != '' then true
        else false
    end as is_analyzable

from {{ source('moma_raw', 'artists') }}
