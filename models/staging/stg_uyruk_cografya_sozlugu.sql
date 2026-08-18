-- Staging: uyruk_cografya_sozlugu
-- Manuel/AI-destekli hazırlanan Nationality -> ulke/bolge eşleme
-- sözlüğü. Değişiklik yok, sadece isim standardizasyonu.

select
    Nationality as nationality_raw,
    adet as artist_count_in_source,
    ulke_bolge as ulke_bolge,
    kategori_notu as kategori_notu

from {{ source('moma_raw', 'uyruk_cografya_sozlugu') }}
