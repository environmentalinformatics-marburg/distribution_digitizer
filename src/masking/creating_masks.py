def mainGeomaskB(workingDir, outDir, n, nMapTypes=1):
    """
    Generate black geographical masks for all TIFF files in the input directory.
    Processes multiple map types (1, 2, ...).

    Args:
        workingDir (str): Working directory containing input and output directories.
        outDir (str): Output directory (e.g., output_2025-09-26_13-16-11).
        n (int): Size parameter for the morphological structuring element.
        nMapTypes (int): Number of map types (1 or 2). Used to limit processing.
    """
    try:
        # --- Finde alle map-type Ordner ---
        map_type_dirs = []
        for name in os.listdir(outDir):
            full = os.path.join(outDir, name)
            if os.path.isdir(full) and name.isdigit():
                map_type_dirs.append(full)

        # --- Nur die ersten nMapTypes verarbeiten ---
        map_type_dirs = map_type_dirs[:int(nMapTypes)]

        if not map_type_dirs:
            print("⚠️ No map-type folders found in output/")
            return

        # --- Jeden map-type Ordner einzeln verarbeiten ---
        for map_dir in map_type_dirs:
            map_type = os.path.basename(map_dir)
            print(f"\n=== Processing map type folder: {map_type} ===")

            # Input und Output für diesen Typ
            inputDir = os.path.join(map_dir, "maps", "pointFiltering")
            outputDir = os.path.join(map_dir, "masking_black")

            # Erstelle den Output-Ordner
            os.makedirs(outputDir, exist_ok=True)

            # --- Alle TIFs verarbeiten ---
            for file in glob.glob(os.path.join(inputDir, "*.tif")):
                print(f"Processing: {os.path.basename(file)}")
                geomask(file, outputDir, n)

        print("\n✓ Black masking completed for all map types.")

    except Exception as e:
        print("An error occurred in mainGeomaskB:", e)
