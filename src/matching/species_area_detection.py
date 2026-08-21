# ============================================================
# File: species_area_detection.py
# Author: Spaska Forteva
#
# Description:
# Detect species distribution contours based on RGB colors
# selected interactively by the user.
#
# The selected colors are used to create a binary mask.
# Contours are then extracted from this mask and saved as
# an output image.
# ============================================================

import cv2
import numpy as np
import os

# ============================================================
# Process all contour maps
# ============================================================
# Creates final masking images for contour-based species
# distributions.
#
# Output:
# - black background
# - detected species areas in red
# - same image dimensions and filename as input
# ============================================================

def process_species_area_maps(
    input_dir,
    output_dir,
    colors,
    tolerance=10,
    border_margin=0,
    debug=False
):

    os.makedirs(output_dir, exist_ok=True)

    # --------------------------------------------------------
    # Find all TIFF maps
    # --------------------------------------------------------
    image_files = [
        file for file in os.listdir(input_dir)
        if file.lower().endswith((".tif", ".tiff"))
    ]

    for filename in image_files:

        image_path = os.path.join(
            input_dir,
            filename
        )

        image = cv2.imread(image_path)

        if image is None:
            print("Could not read image:", image_path)
            continue

        image_int = image.astype(np.int16)

        # ----------------------------------------------------
        # Empty binary mask
        # ----------------------------------------------------
        mask = np.zeros(
            image.shape[:2],
            dtype=np.uint8
        )

        # ----------------------------------------------------
        # Detect selected colors
        # ----------------------------------------------------
        for color in colors:

            r, g, b = map(int, color)

            target = np.array(
                [b, g, r],
                dtype=np.int16
            )

            difference = np.abs(
                image_int - target
            )

            color_pixels = np.all(
                difference <= tolerance,
                axis=2
            )

            mask[color_pixels] = 255

        # ----------------------------------------------------
        # Remove user-defined border
        # ----------------------------------------------------
        if border_margin > 0:

            margin = int(border_margin)

            mask[:margin, :] = 0
            mask[-margin:, :] = 0
            mask[:, :margin] = 0
            mask[:, -margin:] = 0

        # ----------------------------------------------------
        # Create final masking image
        #
        # Background = black
        # Species area = red
        # OpenCV uses BGR -> (0, 0, 255)
        # ----------------------------------------------------
        final_mask = np.zeros_like(image)

        final_mask[mask > 0] = (0, 0, 255)

        # ----------------------------------------------------
        # Save with original filename
        # ----------------------------------------------------
        output_path = os.path.join(
            output_dir,
            filename
        )

        cv2.imwrite(
            output_path,
            final_mask
        )

        if debug:
            print(
                "Processed:",
                filename,
                "- detected pixels:",
                np.count_nonzero(mask)
            )

    return len(image_files)

def detect_species_contour(
    image_path,
    output_dir,
    colors,
    tolerance=10,
    border_margin=0,
    debug=False
):
    """
    Detect species contours based on user-selected RGB colors.

    Parameters
    ----------
    image_path : str
        Path to input map.

    output_dir : str
        Directory for result image.

    colors : list
        RGB colors selected by the user.
        Example:
        [[89, 95, 95],
         [90, 96, 98],
         [98, 102, 103]]

    tolerance : int
        Allowed RGB deviation.

    debug : bool
        Print debug information.

    Returns
    -------
    str
        Path to saved contour image.
    """

    try:

        # ----------------------------------------------------
        # Load image
        # ----------------------------------------------------
        image = cv2.imread(image_path)

        if image is None:
            print("Could not read image:", image_path)
            return None

        os.makedirs(output_dir, exist_ok=True)

        # OpenCV uses BGR
        image_int = image.astype(np.int16)

        # Empty mask
        mask = np.zeros(
            image.shape[:2],
            dtype=np.uint8
        )

        # ----------------------------------------------------
        # Find all selected colors
        # ----------------------------------------------------
        for color in colors:

            r, g, b = map(int, color)

            target = np.array(
                [b, g, r],
                dtype=np.int16
            )

            difference = np.abs(
                image_int - target
            )

            color_pixels = np.all(
                difference <= tolerance,
                axis=2
            )

            mask[color_pixels] = 255

        # ----------------------------------------------------
        # Remove user-defined border area from binary mask
        # ----------------------------------------------------
        if border_margin > 0:
        
            margin = int(border_margin)
        
            mask[:margin, :] = 0
            mask[-margin:, :] = 0
            mask[:, :margin] = 0
            mask[:, -margin:] = 0
        
        
        # ----------------------------------------------------
        # Find contours AFTER removing the border
        # ----------------------------------------------------
        contours, _ = cv2.findContours(
            mask,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE
        )
      

        # ----------------------------------------------------
        # Draw detected contours
        # ----------------------------------------------------
        result = image.copy()

        cv2.drawContours(
            result,
            contours,
            -1,
            (0, 0, 255),
            2
        )

        # ----------------------------------------------------
        # Save result
        # ----------------------------------------------------
        filename = (
            os.path.splitext(
                os.path.basename(image_path)
            )[0]
            + "_species_contour.png"
        )

        output_path = os.path.join(
            output_dir,
            filename
        )

        cv2.imwrite(
            output_path,
            result
        )

        if debug:
            print("\n=== SPECIES CONTOUR DETECTION ===")
            print("Image:", image_path)
            print("Colors:", colors)
            print("Tolerance:", tolerance)
            print("Border margin:", border_margin)
            print("Matching pixels:", np.count_nonzero(mask))
            print("Contours found:", len(contours))
            print("Saved:", output_path)
            print("=================================\n")

        return output_path

    except Exception as e:

        print(
            "Error in detect_species_contour:",
            e
        )

        return None
      
def mainSpeciesAreaDetection(
    workingDir,
    outDir,
    colors,
    tolerance=10,
    border_margin=0,
    nMapTypes=1,
    debug=False
):
    """
    Process species area detection for all map types.

    For each map type:
    - reads aligned maps from maps/align
    - creates the required output directory
    - processes all maps using the selected contour colors
    """

    total_processed = 0

    # --------------------------------------------------------
    # Process all map types
    # --------------------------------------------------------
    for i in range(1, int(nMapTypes) + 1):

        map_type = str(i)

        input_dir = os.path.join(
            outDir,
            map_type,
            "maps",
            "align"
        )

        output_dir = os.path.join(
            outDir,
            map_type,
            "masking_black",
            "pointFiltering"
        )

        # ----------------------------------------------------
        # Check input
        # ----------------------------------------------------
        if not os.path.isdir(input_dir):
            print(
                f"⚠️ Input directory not found for "
                f"map type {map_type}: {input_dir}"
            )
            continue

        # ----------------------------------------------------
        # Create output directory
        # ----------------------------------------------------
        os.makedirs(
            output_dir,
            exist_ok=True
        )

        if debug:
            print("\n====================================")
            print("SPECIES AREA DETECTION")
            print("Map type:", map_type)
            print("Input:", input_dir)
            print("Output:", output_dir)
            print("====================================")

        # ----------------------------------------------------
        # Process all maps of this map type
        # ----------------------------------------------------
        number_processed = process_species_area_maps(
            input_dir=input_dir,
            output_dir=output_dir,
            colors=colors,
            tolerance=tolerance,
            border_margin=border_margin,
            debug=debug
        )

        total_processed += number_processed

        print(
            f"✅ Map type {map_type}: "
            f"{number_processed} maps processed"
        )

    print(
        f"\n✅ Total species area maps processed: "
        f"{total_processed}"
    )

    return total_processed
