import pandas as pd
import numpy as np
from scipy.interpolate import Rbf

# Einlesen der CSV-Dateien
points_csv_path = "D:/distribution_digitizer/data/input/templates/geopoints/gcp_point_map1.points"
input_csv_path = "D:/test/output_2024-07-12_08-18-21/maps/csvFiles/coordinates.csv"

# Ursprüngliche Koordinaten-Datei einlesen
df = pd.read_csv(input_csv_path)

# Punkte-Datei einlesen
points_df = pd.read_csv(points_csv_path)

# Überprüfen der Daten in points_df
print("Punkte-DF (points_df) Kopfzeilen:")
print(points_df.head())

# Überprüfen der Bereiche der Koordinaten
print("Min und Max Werte der sourceX und sourceY:")
print(points_df[['sourceX', 'sourceY']].min())
print(points_df[['sourceX', 'sourceY']].max())

print("Min und Max Werte der X_WGS84 und Y_WGS84:")
print(df[['X_WGS84', 'Y_WGS84']].min())
print(df[['X_WGS84', 'Y_WGS84']].max())

# Erstellen der RBF-Interpolatoren für die Koordinatentransformation
rbf_x = Rbf(points_df['sourceX'], points_df['sourceY'], points_df['mapX'], function='linear')
rbf_y = Rbf(points_df['sourceX'], points_df['sourceY'], points_df['mapY'], function='linear')

# Transformation der Koordinaten
df['real_X'] = rbf_x(df['X_WGS84'], df['Y_WGS84'])
df['real_Y'] = rbf_y(df['X_WGS84'], df['Y_WGS84'])

# Überprüfen der Ergebnisse
print("Transformierte Koordinaten:")
print(df[['X_WGS84', 'Y_WGS84', 'real_X', 'real_Y']].head())

# Fehlende Werte überprüfen
missing_real_coords = df[df['real_X'].isnull() | df['real_Y'].isnull()]
if not missing_real_coords.empty:
    print("Fehlende reale Koordinaten für folgende Punkte:")
    print(missing_real_coords)

# Transformierte Koordinaten in die ursprüngliche Datei speichern
output_csv_path = "D:/test/output_2024-07-12_08-18-21/maps/csvFiles/coordinates_transformed.csv"
df.to_csv(output_csv_path, index=False)

print(f"Die Datei wurde erfolgreich transformiert und gespeichert unter {output_csv_path}")
