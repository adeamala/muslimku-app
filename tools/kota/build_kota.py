#!/usr/bin/env python3
"""Builds assets/data/kota.json: MyQuran city ids with coordinates.

The phone picks the nearest MyQuran city from this table, so "Pakai lokasi saya"
needs no geocoder and the position never leaves the phone.

Sources:
  - MyQuran v2  GET https://api.myquran.com/v2/sholat/kota/semua  (ids + names)
  - Wikidata (CC0) SPARQL: regencies (Q3191695) and cities (Q3199141) of
    Indonesia with coordinates (P625):
      SELECT ?item ?itemLabel ?coord ?type WHERE {
        VALUES ?type { wd:Q3191695 wd:Q3199141 }
        ?item wdt:P31 ?type ; wdt:P625 ?coord .
        SERVICE wikibase:label { bd:serviceParam wikibase:language "id,en". } }
  - MANUAL below: places Wikidata names differently (renamed regencies, the
    islands MyQuran lists separately). Approximate town centres.

Usage: build_kota.py kota_semua.json wikidata.json ../../assets/data/kota.json
"""
import json
import re
import sys

MANUAL = {
    '1205': (-7.3257, 108.3534),  # KAB. CIAMIS (Ciamis)
    '1301': (-6.1754, 106.8272),  # KOTA JAKARTA (Monas)
    '1302': (-5.7457, 106.6137),  # KAB. KEPULAUAN SERIBU (Pulau Pramuka)
    '3005': (-1.1689, 119.3712),  # KAB. MAMUJU UTARA, now Pasangkayu
    '3107': (-7.9833, 131.3000),  # KAB. MALUKU TENGGARA BARAT, now Kep. Tanimbar (Saumlaki)
    '3211': (0.7333, 127.5667),  # KOTA SOFIFI
    '3212': (0.7333, 127.5667),  # KOTA SOFIFI (MyQuran lists it twice)
    '3330': (-1.8833, 136.2333),  # KAB. YAPEN WAROPEN, now Kep. Yapen (Serui)
    '0225': (2.3333, 99.0667),  # KAB. TOBA SAMOSIR, now Toba (Balige)
    '0508': (0.9833, 107.5667),  # PULAU TAMBELAN KAB. BINTAN
    '0510': (2.5167, 109.0500),  # PULAU SERASAN KAB. NATUNA
    '0511': (3.0000, 107.7833),  # PULAU MIDAI KAB. NATUNA
    '0512': (4.7167, 107.9833),  # PULAU LAUT KAB. NATUNA
}
# Same place, different spelling in Wikidata.
ALIAS = {'padangsidempuan': 'padangsidimpuan'}


def norm(name):
    name = re.sub(r'^(kabupaten|kab\.|kota administrasi|kota adm\.|kota)\s+', '', name.lower().strip())
    return re.sub(r'[^a-z0-9]', '', name)


def main(kota_path, wikidata_path, out_path):
    cities = json.load(open(kota_path))['data']
    rows = json.load(open(wikidata_path))['results']['bindings']
    places = {}
    for row in rows:
        kind = 'kab' if row['type']['value'].endswith('Q3191695') else 'kota'
        lng, lat = (float(v) for v in re.findall(r'-?\d+\.?\d*', row['coord']['value'])[:2])
        places.setdefault((kind, norm(row['itemLabel']['value'])), (lat, lng))
    out, missing = [], []
    for city in cities:
        cid, name = city['id'], city['lokasi']
        kind = 'kab' if name.upper().startswith('KAB') else 'kota'
        key = norm(re.sub(r'^(KAB\.|KOTA ADM\.|KOTA)\s*', '', name))
        point = MANUAL.get(cid) or places.get((kind, ALIAS.get(key, key)))
        if point is None:
            missing.append(f'{cid} {name}')
            continue
        out.append({'id': cid, 'n': name, 'lat': round(point[0], 4), 'lng': round(point[1], 4)})
    out.sort(key=lambda c: c['id'])
    with open(out_path, 'w') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{len(out)} cities written, {len(missing)} without coordinates: {missing}')


if __name__ == '__main__':
    main(*sys.argv[1:4])
