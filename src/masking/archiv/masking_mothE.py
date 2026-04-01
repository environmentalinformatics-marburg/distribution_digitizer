import cv2
import os
import numpy as np

#Karten-ID oder Dateiname der Karte.
# Georeferenzierte Eckpunkte: Die Eckkoordinaten der Karte nach der Georeferenzierung (z.B. untere linke und obere rechte Ecke).
# Konturpunkte: Eine Liste von X- und Y-Koordinaten für die Punkte, die die Kontur des Polygons bilden.
# Fläche des Polygons: Berechnete Fläche des Polygons.
# Umfang des Polygons: Der Umfang des Polygons.
# Beschriftung oder Klassifizierung: Wenn die Karte thematisch ist, kannst du Informationen wie Gebietstyp, Region oder andere relevante Details speichern.


# Verzeichnis, das die extrahierten Karten enthält
cards_dir = 'D:/test/output_2024-10-04_11-57-39/maps/matching/'

# Verzeichnis für die Speicherung der Masken
mask_output_dir = 'D:/test/output_2024-10-04_11-57-39/masking/'

# Stelle sicher, dass das Maskenausgabe-Verzeichnis existiert
if not os.path.exists(mask_output_dir):
    os.makedirs(mask_output_dir)

# Funktion zur Erstellung einer Maske für dunkle Konturen
def create_mask(image):
    # Wandle das Bild in Graustufen um (falls nicht bereits in Graustufen)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image
    
    # Invertiere das Bild, da wir an den dunklen Konturen interessiert sind
    inverted = cv2.bitwise_not(gray)
    
    # Wende Schwellenwertbildung (Thresholding) an, um dunkle Konturen zu extrahieren
    _, mask = cv2.threshold(inverted, 50, 255, cv2.THRESH_BINARY)  # 50 ist der Schwellenwert
    
    return mask

# Gehe durch alle Dateien im Kartenverzeichnis
for card_filename in os.listdir(cards_dir):
    if card_filename.endswith('.png') or card_filename.endswith('.jpg') or card_filename.endswith('.tif'):
        # Pfad zur Kartenbilddatei
        card_path = os.path.join(cards_dir, card_filename)

        # Lade die Karte
        card = cv2.imread(card_path)

        # Erstelle die Maske für die dunklen Konturen
        mask = create_mask(card)

        # Speichere die Maske
        mask_output_path = os.path.join(mask_output_dir, f'mask_{card_filename}')
        cv2.imwrite(mask_output_path, mask)

        print(f'Maske für {card_filename} gespeichert unter {mask_output_path}')
