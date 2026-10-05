#!/usr/bin/env python3
"""Download the full 2015 US flight delays dataset used by this project into data/raw_full/ and verify SHA-256.

Origin  : US Department of Transportation, Bureau of Transportation Statistics (BTS), Airline On-Time Performance data
          https://www.transtats.bts.gov/ (carrier on-time reporting, calendar year 2015)
Kaggle  : https://www.kaggle.com/datasets/usdot/flight-delays (flights.csv, airlines.csv, airports.csv)
Mirror  : https://huggingface.co/datasets/hsanchezp/us-dot-flight-delays-2015 (the same Kaggle files as Parquet,
          plus cancellation_codes); identical copy at https://huggingface.co/datasets/librown/us-dot-flight-delays-2015
Licence : CC0 1.0 Public Domain (Kaggle listing; BTS data is a US federal government work)
"""
import hashlib, pathlib, sys, urllib.request

BASE = "https://huggingface.co/datasets/{repo}/resolve/main/{name}"
REPOS = ["hsanchezp/us-dot-flight-delays-2015", "librown/us-dot-flight-delays-2015"]
FILES = {  # name: (bytes, sha256)
    "flights.parquet": (144139267, "4aaf9b41c05eee111cde9dac2c2c0bd08c921fc57e089d145171976925907a14"),
    "airlines.parquet": (645, "e3a637b31fd80f945c567d13d0e38455e94529702c87cdf7fdd13c688c34ed7f"),
    "airports.parquet": (17125, "d10592a7bd2c9bea2fac1a0e6b0e41a879f092674ccf9ef5b3d1e8dd38f34468"),
    "cancellation_codes.parquet": (462, "5a2ad06b20cba686bb87dfbb2471de9a9537a2769f60100705d79b8f3255356b"),
}


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


out = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw_full"
out.mkdir(parents=True, exist_ok=True)
ok = True
for name, (size, digest) in FILES.items():
    p = out / name
    for repo in REPOS:
        if p.exists() and sha(p) == digest:
            break
        url = BASE.format(repo=repo, name=name)
        print("downloading", url, flush=True)
        try:
            urllib.request.urlretrieve(url, p)
        except Exception as e:  # try the next mirror
            print("  failed:", e)
    good = p.exists() and sha(p) == digest
    ok &= good
    print(f"{name} {p.stat().st_size if p.exists() else 0:,} bytes  {'OK' if good else 'CHECKSUM MISMATCH / MISSING'}")
sys.exit(0 if ok else 1)
