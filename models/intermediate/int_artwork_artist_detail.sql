-- Intermediate: artwork_artist_detail
-- Gender ve Nationality analizinin üzerinden yürüyeceği ana tablo.
-- 428 farklı Gender değeri 5 kategoriye indirildi (bkz. bigquery_
-- sorgulari.md, bölüm 10). Nationality, uyruk_cografya_sozlugu ile
-- LEFT JOIN edilip ulke_bolge sütunu kazandırıldı.
--
-- Kaynak sorgu: bigquery_sorgulari.md, bölüm 10

{{ config(materialized='table') }}

select
    l.object_id,
    a.constituent_id,
    a.display_name,
    a.artist_bio,
    a.is_analyzable,
    a.gender_raw,
    case
        when a.gender_raw = 'male' then 'male'
        when a.gender_raw in ('female', 'female (transwoman)', 'transgender woman') then 'female'
        when a.gender_raw in ('non-binary', 'gender non-conforming', 'woman, non-binary') then 'non-binary/diğer'
        when a.gender_raw = 'male (trans? ftm?)' then 'belirsiz'
        when a.gender_raw is null then 'bilinmiyor'
        else 'diger'
    end as gender_kategori,
    a.nationality_raw,
    coalesce(s.ulke_bolge, 'Unknown') as ulke_bolge,
    s.kategori_notu,
    a.begin_date,
    a.end_date,
    a.wiki_qid

from {{ ref('int_artwork_artist_link') }} l
join {{ ref('stg_artists') }} a
    on cast(l.constituent_id as int64) = a.constituent_id
left join {{ ref('stg_uyruk_cografya_sozlugu') }} s
    on trim(a.nationality_raw) = trim(s.nationality_raw)
