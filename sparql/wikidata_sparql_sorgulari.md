[wikidata_sparql_sorgulari.md](https://github.com/user-attachments/files/31409065/wikidata_sparql_sorgulari.md)
# MoMA Capstone — Wikidata SPARQL Sorgu Arşivi

Bu proje kapsamında ilk kez kullanılan SPARQL sorgu dilinin test ve
uygulama sürecinin kaydı. Amaç: Artists tablosundaki Wiki_QID'si dolu
sanatçılar için akım (movement), doğum yeri (birthplace) ve vatandaşlık
(citizenship) bilgisini Wikidata'dan çekmek.

Kullanılan property kodları:
- **P135** = akım/hareket (movement)
- **P19** = doğum yeri (place of birth)
- **P27** = vatandaşlık (country of citizenship)

Sorgu editörü: https://query.wikidata.org

---

## 1. İlk deneme — tek QID, label servisiyle (BAŞARISIZ)

```sparql
SELECT ?artist ?artistLabel ?movement ?movementLabel ?birthplace ?birthplaceLabel ?citizenship ?citizenshipLabel
WHERE {
  VALUES ?artist { wd:Q5593 }
  OPTIONAL { ?artist wdt:P135 ?movement. }
  OPTIONAL { ?artist wdt:P19 ?birthplace. }
  OPTIONAL { ?artist wdt:P27 ?citizenship. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
```

**Sonuç:** "Unknown error". Sebep tam netleşmedi, muhtemelen SELECT
satırındaki hem ham hem Label'lı değişkenlerin birlikte istenmesi
karışıklık yarattı.

Not: Q5593 = Pablo Picasso (test amaçlı seçildi, doğrulandı).

---

## 2. Basitleştirilmiş test — label servisi olmadan (BAŞARILI)

```sparql
SELECT ?artist ?movement ?birthplace ?citizenship
WHERE {
  VALUES ?artist { wd:Q5593 }
  OPTIONAL { ?artist wdt:P135 ?movement. }
  OPTIONAL { ?artist wdt:P19 ?birthplace. }
  OPTIONAL { ?artist wdt:P27 ?citizenship. }
}
```

**Sonuç:** 3 satır geldi (Picasso'nun birden fazla akıma bağlı olduğu
görüldü — çoka-çok ilişkinin ilk kanıtı). QID formatında sonuç (ör.
`wd:Q39427`), henüz okunaklı değil.

---

## 3. Label servisi ile düzeltilmiş hali (BAŞARILI)

```sparql
SELECT ?artist ?movementLabel ?birthplaceLabel ?citizenshipLabel
WHERE {
  VALUES ?artist { wd:Q5593 }
  OPTIONAL { ?artist wdt:P135 ?movement. }
  OPTIONAL { ?artist wdt:P19 ?birthplace. }
  OPTIONAL { ?artist wdt:P27 ?citizenship. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
```

**Sonuç:** 3 satır, okunaklı:
| movementLabel | birthplaceLabel | citizenshipLabel |
|---|---|---|
| surrealism | Málaga | Spain |
| cubism | Málaga | Spain |
| Post-impressionism | Málaga | Spain |

Çözüm netleşti: sadece Label'lı değişkenleri SELECT etmek, ham
değişkenleri SELECT satırından çıkarmak hatayı gideriyor.

---

## 4. Toplu sorgu — Python ile otomatikleştirme (Colab)

Wikidata'nın URL uzunluk sınırı nedeniyle 3.224 QID tek seferde
gönderilemiyor. 200'erli gruplara bölünüp ayrı istekler olarak
gönderildi.

```python
import pandas as pd
import requests
import time

# QID listesini oku (BigQuery'den CSV olarak export edildi)
qid_df = pd.read_csv('/content/drive/MyDrive/MoMA - Capstone/artists_qid.csv')
qids = qid_df['Wiki_QID'].dropna().unique().tolist()
print(f"Toplam QID sayısı: {len(qids)}")

url = "https://query.wikidata.org/sparql"
headers = {'User-Agent': 'MoMA-Capstone-Research/1.0'}

def build_query(qid_batch):
    values = " ".join([f"wd:{q}" for q in qid_batch])
    return f"""
    SELECT ?artist ?movementLabel ?birthplaceLabel ?citizenshipLabel
    WHERE {{
      VALUES ?artist {{ {values} }}
      OPTIONAL {{ ?artist wdt:P135 ?movement. }}
      OPTIONAL {{ ?artist wdt:P19 ?birthplace. }}
      OPTIONAL {{ ?artist wdt:P27 ?citizenship. }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    """

batch_size = 200
all_results = []

for i in range(0, len(qids), batch_size):
    batch = qids[i:i+batch_size]
    query = build_query(batch)
    response = requests.get(url, params={'query': query, 'format': 'json'}, headers=headers)

    if response.status_code == 200:
        data = response.json()['results']['bindings']
        for row in data:
            all_results.append({
                'artist_qid': row['artist']['value'].split('/')[-1],
                'movement': row.get('movementLabel', {}).get('value'),
                'birthplace': row.get('birthplaceLabel', {}).get('value'),
                'citizenship': row.get('citizenshipLabel', {}).get('value'),
            })
        print(f"Grup {i//batch_size + 1} tamam: {len(data)} satır geldi")
    else:
        print(f"Grup {i//batch_size + 1} HATA: {response.status_code}")

    time.sleep(1)  # Wikidata sunucusunu yormamak için

wikidata_results = pd.DataFrame(all_results)
print(f"\nToplam satır: {len(wikidata_results)}")
```

**Sonuç:** 17 grup, hepsi başarılı, hiç hata yok. Toplam **4.877 satır**
(3.224 benzersiz QID — bazı sanatçıların birden fazla akım/vatandaşlık
kaydı olduğu için satır sayısı QID sayısından fazla).

Örnek satırlar:
- Q11223 (US Army Air Forces), Q11224 (US Coast Guard) → movement: None
  (kurumların doğal olarak akımı olmuyor — bu, ek bir kurum filtresi
  gerektirmeden kurumları otomatik ayıklıyor)
- Q46408 → "American modernism", "Sun Prairie", "United States"
- Q53003 → aynı QID için iki farklı citizenship kaydı: "Italy" ve
  "Kingdom of Italy" (tarihsel isim farklılığı, uyruk sözlüğünde
  normalize edilecek türden bir örnek)

---

## 5. Sonucu kaydetme

```python
# Drive'a CSV olarak kaydet
wikidata_results.to_csv('/content/drive/MyDrive/MoMA - Capstone/wikidata_results.csv', index=False)

# BigQuery'ye ayrı tablo olarak yükle
!pip install pandas-gbq --quiet
wikidata_results.to_gbq('moma_raw.wikidata_enrichment', project_id=PROJECT_ID, if_exists='replace')
```

**Neden ayrı tablo:** Bir sanatçının birden fazla akımı olabildiği için
(bire-çok ilişki), bu veri Artists tablosunun ana yapısını bozmadan
köprü tablo olarak tutuldu. Join, Wiki_QID (Artists) ↔ artist_qid
(wikidata_enrichment) üzerinden yarına bırakıldı.

---

## Öğrenilen SPARQL temelleri (referans için)

- **Triple mantığı:** Wikidata'da her bilgi özne-yüklem-nesne üçlüsü
  olarak saklanır (`?artist wdt:P135 ?movement` = "sanatçının akımı X'tir").
- **QID:** Her varlığın (kişi, yer, kavram) benzersiz kodu (`Q` ile başlar).
- **PID:** Her ilişkinin/özelliğin benzersiz kodu (`P` ile başlar).
- **VALUES bloğu:** Birden fazla QID'i aynı sorguda test etmek için
  kullanılır, aralarına sadece boşluk bırakılır.
- **OPTIONAL bloğu:** SQL'deki LEFT JOIN'e benzer — o özelliğin olmadığı
  durumlarda satırı düşürmez, boş bırakır.
- **SERVICE wikibase:label:** QID'leri okunaklı isimlere çevirir, dil
  parametresi (`"en"`) belirtilmesi gerekir.
- **URL uzunluk sınırı:** Çok sayıda QID tek seferde gönderilemez,
  gruplara bölünmesi gerekir (bu projede 200'erli gruplar kullanıldı).
