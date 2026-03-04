import csv
import json
from pathlib import Path

# Paths (all relative to repo root)
SEEDS_PATH = Path("apps/web/data/seeds/countries.json")
ICP_PATH = Path("data/raw/icp_latest.csv")
BASE_PATH = Path("data/raw/affordability_base.csv")

def main():
    # --- Load seeds (your app's country list) ---
    with SEEDS_PATH.open(encoding="utf-8") as f:
        seeds = json.load(f)

    seeds_by_iso2 = {}
    for s in seeds:
        iso2 = (s.get("iso2") or "").upper()
        if not iso2:
            continue
        seeds_by_iso2[iso2] = s

    # --- Load ICP latest data ---
    with ICP_PATH.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        icp_by_iso3 = {}
        for row in reader:
            iso3 = (row.get("iso3") or "").upper()
            if not iso3:
                continue
            try:
                col = float(row["col"])
            except (TypeError, ValueError):
                continue
            icp_by_iso3[iso3] = col

    # --- Load existing affordability_base as overrides (if it exists) ---
    if BASE_PATH.exists():
        with BASE_PATH.open(encoding="utf-8") as f:
            reader = csv.DictReader(f)
            header = reader.fieldnames or []
            overrides = {}
            for row in reader:
                iso2 = (row.get("iso2") or "").upper()
                if not iso2:
                    continue

                col_str = (row.get("col") or "").strip()
                # Only treat as an override if there is a real col value
                if not col_str:
                    continue

                overrides[iso2] = row
    else:
        # Minimal header if file didn't exist yet
        header = ["iso2", "name", "col"]
        overrides = {}

    # Safety: make a backup of the original file if there was one
    if overrides:
        backup_path = BASE_PATH.with_suffix(".backup.csv")
        if not backup_path.exists():
            BASE_PATH.replace(backup_path)
            print(f"Backed up original affordability_base.csv -> {backup_path.name}")
        else:
            print(f"Backup {backup_path.name} already exists; not overwriting.")

    rows_out = []

    for iso2, seed in seeds_by_iso2.items():
        # 1) If you already hand-tuned a row for this country, keep it
        if iso2 in overrides:
            rows_out.append(overrides[iso2])
            continue

        iso3 = (seed.get("iso3") or "").upper()
        col = icp_by_iso3.get(iso3)

        # If ICP has no data, fall back to neutral 1.0 (US-like)
        if col is None:
            col = 1.0

        # Ensure header has at least these columns
        for base_col in ["iso2", "name", "col"]:
            if base_col not in header:
                header.append(base_col)

        # Create a blank row with the same columns as existing CSV
        row = {field: "" for field in header}

        # Fill the important fields
        row["iso2"] = iso2
        row["name"] = seed.get("name", iso2)
        row["col"] = f"{col:.6f}"

        rows_out.append(row)

    # Also keep any override rows that don't appear in seeds (edge cases)
    for iso2, row in overrides.items():
        if iso2 not in seeds_by_iso2:
            rows_out.append(row)

    # --- Write the new affordability_base.csv ---
    with BASE_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows_out)

    print(f"Wrote {BASE_PATH} with {len(rows_out)} rows.")
    
    for r in rows_out[:5]:
        print(r.get("iso2"), r.get("name"), r.get("col"))

if __name__ == "__main__":
    main()