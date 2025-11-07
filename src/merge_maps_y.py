import pandas as pd
from pathlib import Path
import glob

# === Pfade anpassen ===
small_dir = r"D:/test/archiv/output_2025-03-04_15-42-16_map_2_all/pagerecords"   # Ordner mit vielen kleinen CSVs

big_csv   = r"D:/test/archiv/output_2025-03-04_15-42-16_map_2_all/spatial_final_data_with_new_pagerecordsFiles_map_2.csv"                              # große CSV (Semikolon-separiert, ohne Header)
out       = r"D:/test/merged_by_map_name.csv"                     # Ergebnis

map_col_idx = 3   # 0-basiert: 3 = 4. Spalte in big_csv, enthält map_name
append_y    = True

# === kleine CSVs einlesen & zusammenfassen ===
frames = []
for f in glob.glob(str(Path(small_dir) / "*.csv")):
    try:
        df = pd.read_csv(f)
        key_col = "map_name" if "map_name" in df.columns else "file_name"
        tmp = df[[key_col, "y"]].copy()
        tmp["key"] = tmp[key_col].astype(str).map(lambda p: Path(p).name)
        frames.append(tmp[["key", "y"]])
    except Exception as e:
        print(f"[WARN] überspringe {f}: {e}")

if not frames:
    raise RuntimeError("Keine gültigen CSVs in small_dir gefunden")

df_small = pd.concat(frames, ignore_index=True)
df_small = df_small.drop_duplicates("key")

# === große CSV einlesen ===
df_big = pd.read_csv(big_csv, sep=";", header=None, engine="python")
df_big["key"] = df_big[map_col_idx].astype(str).map(lambda p: Path(p).name)

# === mergen ===
merged = df_big.merge(df_small, on="key", how="left")

# === optional: neue Spalte mit y im Dateinamen ===
def add_y(name, y):
    try:
        if pd.notna(y):
            yi = int(round(float(y)))
            stem, dot, ext = str(name).rpartition('.')
            return f"{stem}y{yi}.{ext}" if dot else f"{name}y{yi}"
    except Exception:
        pass
    return name

if append_y:
    merged["filename_with_y"] = merged["key"].combine(merged["y"], add_y)

# === schreiben ===
merged.drop(columns=["key"]).to_csv(out, sep=";", index=False, header=False, encoding="utf-8")
print("OK ->", out)
