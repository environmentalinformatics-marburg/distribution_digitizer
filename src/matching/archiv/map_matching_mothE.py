import cv2
import numpy as np
import os

# Verzeichnis, das die Seitenbilder enthält
pages_dir = 'D:/distribution_digitizer/data/input/pages/'

# Verzeichnis, das die Templates enthält
template_dir = 'D:/distribution_digitizer/data/input/templates/maps/'

# Verzeichnis für die Speicherung der ausgeschnittenen Karten
output_dir = 'D:/test/output_2024-10-04_11-57-39/maps/matching/'

# Liste, um die geladenen Templates zu speichern
templates = []

# Durchlaufe alle Dateien im Template-Verzeichnis
for filename in os.listdir(template_dir):
    if filename.endswith('.tif') or filename.endswith('.png') or filename.endswith('.jpg'):
        file_path = os.path.join(template_dir, filename)
        template = cv2.imread(file_path, 0)  # Graustufenmodus
        templates.append((template, filename))

# Gehe durch alle Bilder im Seitenverzeichnis
for page_filename in os.listdir(pages_dir):
    if page_filename.endswith('.tif') or page_filename.endswith('.png') or page_filename.endswith('.jpg'):
        # Kompletter Pfad zum aktuellen Bild
        img_path = os.path.join(pages_dir, page_filename)

        # Lade das Bild (Graustufen und Farbe)
        img = cv2.imread(img_path, 0)  # Graustufenmodus
        img_color = cv2.imread(img_path)  # Farbbild

        # Binärbild durch Schwellenwertbildung erstellen
        _, binary = cv2.threshold(img, 128, 255, cv2.THRESH_BINARY_INV)

        # Morphologische Operationen
        kernel = np.ones((5, 5), np.uint8)
        dilated = cv2.dilate(binary, kernel, iterations=2)
        eroded = cv2.erode(dilated, kernel, iterations=2)

        # Konturen finden
        contours, _ = cv2.findContours(eroded, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Hough-Transformation für Linienerkennung
        lines = cv2.HoughLinesP(eroded, 1, np.pi / 180, threshold=50, minLineLength=30, maxLineGap=10)

        # Liste, um bereits verarbeitete Bereiche zu speichern (um Überschneidungen zu verhindern)
        processed_areas = []

        # Funktion zur Überprüfung, ob ein neuer Bereich bereits bearbeitet wurde
        def is_overlapping(x, y, w, h, processed_areas):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and y < py + ph and y + h > py):
                    return True
            return False

        # Gehe durch die Liste der Templates
        for template, filename in templates:
            template_h, template_w = template.shape[:2]
            
            # Definiere eine Toleranz für die Konturengrößen, basierend auf der Template-Größe
            tolerance = 0.5  # 50% Toleranz auf die Template-Größe
            min_w = int(template_w * (1 - tolerance))
            max_w = int(template_w * (1 + tolerance))
            min_h = int(template_h * (1 - tolerance))
            max_h = int(template_h * (1 + tolerance))

            # Gehe durch die gefundenen Konturen
            for idx, contour in enumerate(contours):
                x, y, w, h = cv2.boundingRect(contour)
                
                if min_w <= w <= max_w and min_h <= h <= max_h and not is_overlapping(x, y, w, h, processed_areas):
                    # Kartenbereich ausschneiden und speichern
                    card = img[y:y+h, x:x+w]
                    cv2.imwrite(f'{output_dir}card_{filename.split(".")[0]}_{page_filename.split(".")[0]}_{idx}.png', card)

                    # Zeichne das Rechteck im Originalbild ein
                    cv2.rectangle(img_color, (x, y), (x + w, y + h), (0, 0, 255), 2)

                    # Bereich zur Liste der verarbeiteten Bereiche hinzufügen
                    processed_areas.append((x, y, w, h))

        # Markiere die erkannten Linien, die die Länge der Templates haben
        if lines is not None:
            for line in lines:
                x1, y1, x2, y2 = line[0]
                length = np.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

                # Überprüfen, ob die Länge der Linie innerhalb der Toleranz liegt
                if (min_w <= length <= max_w) or (min_h <= length <= max_h):
                    cv2.line(img_color, (x1, y1), (x2, y2), (0, 255, 0), 2)  # Grüne Linien zeichnen

        # Speichere das Bild mit den markierten Konturen und Linien
        output_image_path = f'{output_dir}detected_{page_filename}'
        cv2.imwrite(output_image_path, img_color)
