-- Staging: artworks
-- Kaynak tabloda Date temizliği zaten Python (Colab) ile yapıldı
-- (extracted_year, has_production_note, year_confidence sütunları).
-- Bu model sadece kullanılacak sütunları seçip isimlendiriyor,
-- ağır bir dönüşüm yapmıyor.

select
    ObjectID as object_id,
    Title as title,
    Artist as artist_raw,
    ConstituentID as constituent_id_raw,
    Date as date_raw,
    extracted_year,
    has_production_note,
    year_confidence,
    DateAcquired as date_acquired_raw,
    Medium as medium,
    Dimensions as dimensions,
    CreditLine as credit_line,
    Classification as classification,
    Department as department

from {{ source('moma_raw', 'artworks') }}
