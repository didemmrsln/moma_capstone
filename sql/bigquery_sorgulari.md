[bigquery_sorgulari.md](https://github.com/user-attachments/files/31409290/bigquery_sorgulari.md)
# MoMA Capstone — BigQuery SQL Sorgu Arşivi

Bu dosya, proje boyunca BigQuery'de çalıştırılan sorguları, ne aradığımızı,
ne bulduğumuzu ve hangi karara vardığımızı kronolojik sırayla topluyor.
Amaç: Job history süresi dolsa bile hiçbir sorguyu kaybetmemek, dbt
modellerine geçerken doğrudan referans alabilmek.

Proje: `moma-capstone.moma_raw`
Tablolar: `artworks`, `artists`, `wikidata_enrichment`, `uyruk_cografya_sozlugu`

---

## 1. Date sütunu — genel manzara

**Ne aradık:** Date sütununda en sık geçen değerler neler, hangi formatlar var.

```sql
SELECT
  Date,
  COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artworks`
GROUP BY Date
ORDER BY adet DESC
LIMIT 50;
```

**Bulgu:** Temiz yıllar (`"1962"`) üst sıralarda, ama aralık, tahmini ("c."),
önce/sonra, on yıl gibi çok sayıda farklı format olduğu görüldü.

---

## 2. Date sütunu — kalıp sınıflandırması (3 iterasyon)

### Tur 1 — İlk kalıplar

```sql
SELECT
  CASE
    WHEN Date IS NULL OR Date = '' THEN 'boş'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}$') THEN 'temiz_yil'
    WHEN REGEXP_CONTAINS(Date, r'^c\.\s?\d{4}$') THEN 'tahmini_c'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}-\d{2,4}$') THEN 'aralik'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}s$') THEN 'on_yil'
    WHEN REGEXP_CONTAINS(Date, r'printed') THEN 'iki_tarih_printed'
    WHEN LOWER(Date) LIKE '%unknown%' THEN 'unknown'
    WHEN LOWER(Date) LIKE '%n\\.d\\.%' THEN 'nd_kisaltma'
    ELSE 'diger'
  END AS kalip,
  COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artworks`
GROUP BY kalip
ORDER BY adet DESC;
```

**Sonuç:** temiz_yil 100.466 | diger 30.773 (%19) | aralik 16.953 | tahmini_c 6.838 |
nd_kisaltma 2.147 | boş 2.013 | iki_tarih_printed 674 | on_yil 589 | unknown 246

**Karar:** "diger" çok büyük, ikinci tur gerekli.

### "Diğer" kategorisini örnekleme (her turdan önce kullanıldı)

```sql
SELECT DISTINCT Date
FROM `moma-capstone.moma_raw.artworks`
WHERE NOT REGEXP_CONTAINS(Date, r'^\d{4}$')
  AND NOT REGEXP_CONTAINS(Date, r'^c\.\s?\d{4}$')
  AND NOT REGEXP_CONTAINS(Date, r'^\d{4}-\d{2,4}$')
  AND NOT REGEXP_CONTAINS(Date, r'^\d{4}s$')
  AND NOT REGEXP_CONTAINS(Date, r'printed')
  AND LOWER(Date) NOT LIKE '%unknown%'
  AND Date IS NOT NULL AND Date != ''
LIMIT 100;
```

**Bulgu (Tur 1→2 arası):** Kritik keşif — MoMA verisinde tire karakteri normal
kısa çizgi (`-`) değil, **en dash (–)** karakteri. Bu yüzden aralık kalıpları
yakalanamıyordu. Ayrıca "Before 1955", "c. 1930-40", "late 19th century",
"c. 3000 B.C." gibi yeni kalıplar görüldü.

### Tur 2 — en dash düzeltmesi + yeni kalıplar

```sql
SELECT
  CASE
    WHEN Date IS NULL OR Date = '' THEN 'boş'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}$') THEN 'temiz_yil'
    WHEN REGEXP_CONTAINS(Date, r'B\.?C\.?') THEN 'MO_tarih'
    WHEN REGEXP_CONTAINS(Date, r'century') THEN 'yuzyil'
    WHEN REGEXP_CONTAINS(Date, r'^[Bb]efore\s?\d{4}$') THEN 'oncesi'
    WHEN REGEXP_CONTAINS(Date, r'^[Aa]fter\s?\d{4}$') THEN 'sonrasi'
    WHEN REGEXP_CONTAINS(Date, r'^c\.\s?\d{4}\s?-\s?\d{2,4}$') THEN 'tahmini_aralik'
    WHEN REGEXP_CONTAINS(Date, r'^c\.\s?\d{4}$') THEN 'tahmini_c'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}\s?-\s?\d{2,4}$') THEN 'aralik'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}s$') THEN 'on_yil'
    WHEN REGEXP_CONTAINS(Date, r'printed') THEN 'iki_tarih_printed'
    WHEN LOWER(Date) LIKE '%unknown%' THEN 'unknown'
    WHEN REGEXP_CONTAINS(LOWER(Date), r'n\.?\s?d\.?') THEN 'nd_kisaltma'
    ELSE 'diger'
  END AS kalip,
  COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artworks`
GROUP BY kalip
ORDER BY adet DESC;
```

**Not:** Bu sorguda `-` yerine `[-–]` kullanmak gerekiyordu (aşağıdaki Tur 3'te
düzeltildi). Tur 2 sonucu: diger ~24.043 satır (%15).

**Bulgu (Tur 2→3 arası):** Örnekleme tekrarlandığında "September 9, 2022",
"(1908)", "(1946-47)", "Paris, winter 1913-14", "published/executed/cast/
fabricated" gibi üretim fiili kalıpları ve parantez içi tarihler görüldü.

### Tur 3 — final kalıp seti

```sql
SELECT
  CASE
    WHEN Date IS NULL OR Date = '' THEN 'boş'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}$') THEN 'temiz_yil'
    WHEN REGEXP_CONTAINS(Date, r'B\.?C\.?') THEN 'MO_tarih'
    WHEN REGEXP_CONTAINS(Date, r'century') THEN 'yuzyil'
    WHEN REGEXP_CONTAINS(Date, r'^[Bb]efore\s?\d{4}\.?$') THEN 'oncesi'
    WHEN REGEXP_CONTAINS(Date, r'^[Aa]fter\s?\d{4}\.?$') THEN 'sonrasi'
    WHEN REGEXP_CONTAINS(Date, r'^[Bb]egun\s?\d{4}') THEN 'baslangic_begun'
    WHEN REGEXP_CONTAINS(Date, r'revised') THEN 'revize'
    WHEN REGEXP_CONTAINS(Date, r'^[A-Za-z]+\s\d{4}$') THEN 'ay_yil'
    WHEN REGEXP_CONTAINS(Date, r'^[A-Za-z]+\s\d{1,2},?\s\d{4}\.?$') THEN 'tam_tarih'
    WHEN REGEXP_CONTAINS(Date, r'^\d{1,2}\s[A-Za-z]+\s\d{4}$') THEN 'tam_tarih_ters'
    WHEN REGEXP_CONTAINS(Date, r'^\(\d{4}\)$') THEN 'parantez_yil'
    WHEN REGEXP_CONTAINS(Date, r'^\(\d{4}\s?[-–]\s?\d{2,4}\)\.?$') THEN 'parantez_aralik'
    WHEN REGEXP_CONTAINS(LOWER(Date), r'published|executed|cast|fabricated') THEN 'uretim_fiili'
    WHEN REGEXP_CONTAINS(Date, r'^[A-Za-z]+,\s') THEN 'sehir_mevsim'
    WHEN REGEXP_CONTAINS(Date, r'^c[a]?\.?\s?\d{4}\s?[-–]\s?\d{2,4}$') THEN 'tahmini_aralik'
    WHEN REGEXP_CONTAINS(Date, r'^c[a]?\.?\s?\d{4}$') THEN 'tahmini_c'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}\s?[-–]\s?\d{2,4}\.?$') THEN 'aralik'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}/\d{2}\s?[-–]\s?\d{2,4}$') THEN 'egik_cizgi_aralik'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}/\d{4}$') THEN 'egik_cizgi_ikili'
    WHEN REGEXP_CONTAINS(Date, r'^\d{4}s$') THEN 'on_yil'
    WHEN REGEXP_CONTAINS(Date, r'printed') THEN 'iki_tarih_printed'
    WHEN LOWER(Date) LIKE '%unknown%' THEN 'unknown'
    WHEN REGEXP_CONTAINS(LOWER(Date), r'n\.?\s?d\.?') THEN 'nd_kisaltma'
    ELSE 'diger'
  END AS kalip,
  COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artworks`
GROUP BY kalip
ORDER BY adet DESC;
```

**Sonuç:** 25 farklı kalıp tanımlandı. diger ~12.382 satıra düştü (%7.7).

**KARAR (regex yaklaşımının sonu):** Üçüncü tur toplamın yarısını kurtardı
ama azalan getiri noktasına ulaşıldı — kalan satırlar tekil/eşsiz serbest
metin varyasyonları. Kural bazlı sınıflandırmaya devam etmek yerine Python'da
yıl-çıkarma stratejisine geçildi (bkz. Colab notebook, `extract_year_info`
fonksiyonu — bu fonksiyon her satırdan regex ile ilk 4 haneli yılı çıkarıyor,
üretim fiili notunu ayrı sütunda tutuyor).

**Python sonrası sonuç:** 160.699 satırın 156.272'sinde (%97.25) bir referans
yıl değeri çıkarıldı (100.468 tam eşleşme, 55.804 kısmi). 4.427 satırda
(%2.75) yıl çıkarılamadı — bunlar `extracted_year IS NULL` filtresiyle
analiz dışı bırakılacak, ayrı tabloya taşınmadı.

Fonksiyon çalıştıktan sonra üç yeni sütun BigQuery'ye geri yüklendi:
`extracted_year`, `has_production_note`, `year_confidence`.
Satır sayısı korundu: 160.699.

---

## 3. Artworks — diğer sütunların genel taraması

**Ne aradık:** Date dışındaki sütunlarda (Nationality, Gender, Medium,
Department, Classification, Dimensions, CreditLine) boşluk oranı ve
farklı değer sayısı ne kadar.

```sql
SELECT
  COUNTIF(Nationality IS NULL OR Nationality = '') AS nationality_bos,
  COUNT(DISTINCT Nationality) AS nationality_farkli,
  COUNTIF(Gender IS NULL OR Gender = '') AS gender_bos,
  COUNT(DISTINCT Gender) AS gender_farkli,
  COUNTIF(Medium IS NULL OR Medium = '') AS medium_bos,
  COUNT(DISTINCT Medium) AS medium_farkli,
  COUNTIF(Department IS NULL OR Department = '') AS department_bos,
  COUNT(DISTINCT Department) AS department_farkli,
  COUNTIF(Classification IS NULL OR Classification = '') AS classification_bos,
  COUNT(DISTINCT Classification) AS classification_farkli,
  COUNTIF(Dimensions IS NULL OR Dimensions = '') AS dimensions_bos,
  COUNTIF(CreditLine IS NULL OR CreditLine = '') AS creditline_bos
FROM `moma-capstone.moma_raw.artworks`;
```

**Sonuç (160.699 satır):**
| Sütun | Boş | Farklı değer |
|---|---|---|
| Nationality | 1.258 | 1.156 |
| Gender | 1.258 | 8 (ama alt kategori olarak 428 kombinasyon var) |
| Medium | 8.768 | 23.187 |
| Department | 0 | 8 |
| Classification | 1 | 42 |
| Dimensions | 8.336 | — |
| CreditLine | 1.286 | — |

**Karar:** Department ve Classification zaten temiz, dokunmaya gerek yok.
Nationality (Artworks tablosunda) 1.156 farklı değer taşıyor çünkü çoklu
sanatçı satırlarında birden fazla uyruk birleşiyor — bu, Gender sütunundaki
428 farklı değerin de temel sebebi.

---

## 4. Gender sütunu — çoklu sanatçı etkisinin teyidi

```sql
SELECT Gender, COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artworks`
GROUP BY Gender
ORDER BY adet DESC;
```

**Sonuç:** 428 farklı değer. En sık görülenler: `(male)` 123.602, `(female)`
20.242, `()` (boş) 7.368, `(male) (male)` 1.755 gibi tekrarlayan
kombinasyonlar.

**KARAR:** Gender/Nationality temizliği ERTELENDİ. Önce Artists tablosunda
kurum/stüdyo ayrımı yapılacak, sonra sanatçı-eser çoklu ilişki tablosu
kurulacak (her sanatçı ayrı satırda), ancak bu iki adım tamamlandıktan
sonra Gender/Nationality temizliğine dönülecek.

---

## 5. Artists tablosu — genel manzara

```sql
SELECT
  COUNT(*) AS toplam_sanatci,
  COUNTIF(Wiki_QID IS NOT NULL AND Wiki_QID != '') AS wiki_qid_dolu,
  COUNTIF(ArtistBio IS NULL OR ArtistBio = '') AS artistbio_bos,
  COUNTIF(Nationality IS NULL OR Nationality = '' OR Nationality = '()') AS nationality_bos,
  COUNTIF(BeginDate = 0 OR BeginDate IS NULL) AS begindate_bos,
  COUNTIF(Gender IS NULL OR Gender = '' OR Gender = '()') AS gender_bos
FROM `moma-capstone.moma_raw.artists`;
```

**Sonuç (15.932 sanatçı):**
- Wiki_QID dolu: 3.247 (%20.4)
- ArtistBio dolu: %86.4 (2.165 boş)
- Nationality dolu: %84.4 (2.479 boş)
- BeginDate dolu: %78.2 (3.471 boş)
- Gender dolu: %79.4 (3.285 boş)

---

## 6. Artists — kurum/stüdyo tespiti denemeleri

### ArtistBio boş olanları örnekleme

```sql
SELECT DisplayName, ArtistBio, Nationality, BeginDate, EndDate, Wiki_QID
FROM `moma-capstone.moma_raw.artists`
WHERE ArtistBio IS NULL OR ArtistBio = ''
LIMIT 30;
```

**Bulgu:** Çoğunluk kurum/stüdyo (Unidentified Designer, Chicago School of
Design, basın ajansları) ama bazı gerçek kişi isimleri de var (Palme
Berthold, Zlatko Prica) — ArtistBio boşluğu tek başına güvenilir bir
kurum göstergesi değil.

### Anahtar kelime bazlı kurum tespiti (denendi, düşük başarı)

```sql
SELECT
  COUNTIF(
    REGEXP_CONTAINS(LOWER(DisplayName), r'studio|designer|architects|company|inc\.|newsreel|press|news|daily|committee|prefecture|photomaton|school of|unidentified')
  ) AS anahtar_kelimeli_kurum,
  COUNT(*) AS toplam_bio_bos
FROM `moma-capstone.moma_raw.artists`
WHERE ArtistBio IS NULL OR ArtistBio = '';
```

**Sonuç:** Sadece 205/2.165 (%9.5) yakalandı — güvenilir değil.

**KARAR:** İsimden otomatik kurum tespiti terk edildi (yanlış etiketleme
riski). Bunun yerine ArtistBio doluluğu doğrudan analiz filtresi olarak
kullanılacak.

### ArtistBio boş + Gender boş kesişimi (filtre gerekçesi)

```sql
SELECT
  COUNTIF(ArtistBio IS NULL OR ArtistBio = '') AS bio_bos,
  COUNTIF((ArtistBio IS NULL OR ArtistBio = '') AND (Gender IS NULL OR Gender = '')) AS bio_bos_ve_gender_bos,
  COUNTIF((ArtistBio IS NULL OR ArtistBio = '') AND (Gender IS NOT NULL AND Gender != '')) AS bio_bos_ama_gender_dolu
FROM `moma-capstone.moma_raw.artists`;
```

**Sonuç:** bio_bos: 2.165 | bio_bos_ve_gender_bos: 1.608 (%74) |
bio_bos_ama_gender_dolu: 557 (%26)

**FİNAL KARAR:** ArtistBio dolu olan **13.767 sanatçı** (%86.4) analiz
edilebilir küme olarak kabul edildi. ArtistBio boş olan 2.165 sanatçı
(%13.6) analiz dışı bırakıldı — bunların %74'ünde Gender de zaten boş
(muhtemelen kurum), kalan %26'sı belirsiz ama güvenilir ayrım
yapılamadığı için hepsi birlikte dışlandı.

### Kurum örneği doğrulama (ArtistBio'nun bazı kurumlarda da dolu olabildiğinin kanıtı)

```sql
SELECT DisplayName, ArtistBio, Nationality, Wiki_QID
FROM `moma-capstone.moma_raw.artists`
WHERE DisplayName IN ('NASA', 'United States. Army Air Forces', 'U.S. Coast Guard', 'Eastman Kodak Company, Rochester, NY')
```

**Bulgu:** Eastman Kodak Company'nin ArtistBio'su `"American, established
1901"` — gerçek sanatçı formatına çok benziyor. ArtistBio doluluğunun
%100 güvenilir olmadığının kanıtı. Ek filtre uygulanmadı çünkü Wikidata'da
kurumların "akım" (P135) bilgisi doğal olarak boş dönüyor — bu doğal bir
filtre görevi görüyor (bkz. SPARQL sorgu dosyası).

---

## 7. Artists — Nationality analizi

```sql
SELECT Nationality, COUNT(*) AS adet
FROM `moma-capstone.moma_raw.artists`
WHERE ArtistBio IS NOT NULL AND ArtistBio != ''
GROUP BY Nationality
ORDER BY adet DESC;
```

**Sonuç:** 145 farklı değer (Artworks'teki 1.156'ya kıyasla çok daha temiz,
çoklu-sanatçı birleşmesi olmadığı için). En sık: American 5.362, German 986,
British 873...

**Özel durumlar:**
- `null` (468) + `"Nationality unknown"` (135) → birleştirilecek
- `Czechoslovakian` (4) → tarihsel devlet
- `Native American`, `Puerto Rican`, `Scottish`, `Welsh`, `Catalan`,
  `English` gibi 13 değer → ulus-devlet değil, kültürel/etnik kimlik

**Sonraki adım:** Bu 145 değer, `uyruk_cografya_sozlugu.csv` dosyasında
manuel/AI-destekli olarak ülke/bölge eşlemesine dönüştürüldü, ardından
`moma_raw.uyruk_cografya_sozlugu` tablosu olarak BigQuery'ye yüklendi.
Yugoslavian ve Congolese "Unknown" olarak işaretlendi (tek bir ülkeye/
cumhuriyete kesin atanamadıkları için).

---

## 8. QID listesi çekme (SPARQL sorgusu için hazırlık)

```sql
SELECT DisplayName, Wiki_QID
FROM `moma-capstone.moma_raw.artists`
WHERE Wiki_QID IS NOT NULL AND Wiki_QID != ''
  AND ArtistBio IS NOT NULL AND ArtistBio != ''
```

**Sonuç:** 3.224 satır (CSV olarak indirildi, Colab'da SPARQL sorgusuna
temel oluşturdu — bkz. `wikidata_sparql_sorgulari.md`).

---

## Genel özet — tablo durumu (bugün sonu itibariyle)

| Tablo | Satır sayısı | Durum |
|---|---|---|
| `artworks` | 160.699 | Date temizlendi (3 sütun eklendi), diğer sütunlar tarandı |
| `artists` | 15.932 | İncelendi, 13.767'si analiz edilebilir küme olarak işaretlendi |
| `wikidata_enrichment` | 4.877 | 3.224 QID için akım/doğum yeri/uyruk çekildi |
| `uyruk_cografya_sozlugu` | 145 | Nationality → ülke/bölge eşleme sözlüğü |

**Henüz yapılmadı (yarına):** Artists ↔ Wikidata_enrichment ↔
Uyruk_cografya_sozlugu join'i, sanatçı-eser çoklu ilişki tablosu,
post-join Gender/Nationality temizliği.
