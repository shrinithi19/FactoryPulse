"""
Downloads the three public datasets used across M2-M6 into data/raw/.

NASA's Prognostics Center of Excellence data repository and the UCI ML
Repository don't offer stable, scriptable direct-download URLs for these
specific datasets (C-MAPSS and IMS in particular require accepting terms
on NASA's portal; UCI's AI4I 2020 page link can change with site
reorganizations) — so this script does a best-effort download for AI4I
(which does have a stable direct CSV link) and prints manual-download
instructions for C-MAPSS and IMS rather than silently failing or
hardcoding a URL that will break.

Run:
    python scripts/download_datasets.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import requests

RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"

AI4I_URL = (
    "https://archive.ics.uci.edu/static/public/601/"
    "ai4i+2020+predictive+maintenance+dataset.zip"
)


def download_ai4i() -> None:
    target_dir = RAW_DIR / "ai4i_2020"
    target_dir.mkdir(parents=True, exist_ok=True)
    zip_path = target_dir / "ai4i2020.zip"

    print(f"[ai4i_2020] downloading from {AI4I_URL} ...")
    try:
        resp = requests.get(AI4I_URL, timeout=30)
        resp.raise_for_status()
        zip_path.write_bytes(resp.content)
        print(f"[ai4i_2020] saved to {zip_path} — unzip it in place")
    except requests.RequestException as exc:
        print(f"[ai4i_2020] download failed ({exc}) — download manually from:")
        print("  https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset")
        print(f"  and place the extracted CSV under {target_dir}/")


def print_manual_instructions() -> None:
    print(
        "\n[cmapss] NASA's C-MAPSS turbofan dataset requires manual download:\n"
        "  1. Go to https://www.nasa.gov/intelligent-systems-division/ "
        "(search 'Turbofan Engine Degradation Simulation Data Set' / "
        "'C-MAPSS')\n"
        f"  2. Extract train_FD001.txt, test_FD001.txt, RUL_FD001.txt into "
        f"{RAW_DIR / 'cmapss'}/\n"
    )
    print(
        "[ims_bearings] The IMS bearing dataset also requires manual download:\n"
        "  1. Search NASA's prognostics data repository for "
        "'IMS Bearing Dataset'\n"
        f"  2. Extract the test folders (e.g. '1st_test/') into "
        f"{RAW_DIR / 'ims_bearings'}/\n"
    )


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for sub in ("cmapss", "ims_bearings", "ai4i_2020"):
        (RAW_DIR / sub).mkdir(parents=True, exist_ok=True)

    download_ai4i()
    print_manual_instructions()


if __name__ == "__main__":
    sys.exit(main())
