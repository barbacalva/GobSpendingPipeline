import datetime
import hashlib
import html
import logging
import os
import re
import ssl
import urllib.parse
import urllib.request

import boto3

BUCKET = os.environ["TARGET_BUCKET"]
TABLE = os.environ["DDB_TABLE"]

URL = ("https://www.igae.pap.hacienda.gob.es/sitios/igae/es-ES/"
       "Contabilidad/ContabilidadPublica/CPE/EjecucionPresupuestaria/"
       "Paginas/imejecucionpresupuesto.aspx")

ssl_ctx = ssl.create_default_context()
log = logging.getLogger()
log.setLevel(logging.INFO)

MONTH_MAP = {
    "ENERO": 1, "FEBRERO": 2, "MARZO": 3, "ABRIL": 4,
    "MAYO": 5, "JUNIO": 6, "JULIO": 7, "AGOSTO": 8,
    "SEPTIEMBRE": 9, "OCTUBRE": 10, "NOVIEMBRE": 11, "DICIEMBRE": 12,
}

s3 = boto3.client("s3")
ddb = boto3.client("dynamodb")


def _fetch(url: str) -> str:
    with urllib.request.urlopen(url, context=ssl_ctx) as r:
        return r.read().decode("utf-8", errors="ignore")


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _already_saved(file_id: str, sha256: str) -> bool:
    res = ddb.get_item(TableName=TABLE, Key={"file_id": {"S": file_id}})
    return "Item" in res and res["Item"].get("sha256", {}).get("S") == sha256


def _record_save(file_id: str, sha256: str):
    ddb.put_item(
        TableName=TABLE,
        Item={
            "file_id": {"S": file_id},
            "sha256": {"S": sha256},
            "ts": {"S": datetime.datetime.utcnow().isoformat()},
        }
    )


def _parse_links(page: str):
    links = re.findall(r'href="([^"]+?\.xlsx)"', page, flags=re.I)
    out = {}
    for raw in links:
        href = html.unescape(raw)
        dec = urllib.parse.unquote(href)
        m = re.search(
            r'(ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SEPTIEMBRE'
            r'|OCTUBRE|NOVIEMBRE|DICIEMBRE)[\s_/.-]+(\d{4})',
            dec, flags=re.I)
        if not m:
            continue
        month_name = m.group(1).upper()
        year = int(m.group(2))
        key = (year, MONTH_MAP[month_name])
        out.setdefault(key, []).append(href)
    return out


def _classify(filename: str) -> str:
    low = filename.lower()
    if "anexo" in low:
        return "anexo2" if "ii" in low else "anexo1"
    return "cuadros"


def lambda_handler(event, context):
    page = _fetch(URL)
    by_month = _parse_links(page)
    if not by_month:
        raise RuntimeError("Did not found any XLSX in the page")

    latest_key = max(by_month.keys())
    links = by_month[latest_key]
    year, month_num = latest_key
    month_name = [k for k, v in MONTH_MAP.items() if v == month_num][0].capitalize()

    status = {"year": year, "month": month_name, "files": []}

    for href in links:
        if not href.startswith("http"):
            href = "https://www.igae.pap.hacienda.gob.es" + href
        fname = os.path.basename(urllib.parse.unquote(href))
        category = _classify(fname)
        s3_key = f"IGAE/EPAGE/{year}/{month_name}/{category}.xlsx"
        file_id = f"{year}-{month_name}-{category}"

        log.info("Downloading %s (%s)", href, category)
        data = urllib.request.urlopen(href, context=ssl_ctx).read()
        sha = _hash(data)

        if _already_saved(file_id, sha):
            log.info("→ no changes in (%s)", file_id)
            status["files"].append({"file": s3_key, "status": "skip"})
            continue

        s3.put_object(Bucket=BUCKET, Key=s3_key, Body=data)
        _record_save(file_id, sha)
        log.info("→ saved in S3 %s", s3_key)
        status["files"].append({"file": s3_key, "status": "stored"})

    status["done"] = True
    return status
