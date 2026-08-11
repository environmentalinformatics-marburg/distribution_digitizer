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



def detect_species_contour(
    image_path,
    output_dir,
    colors,
    tolerance=10,
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
        # Find contours
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
