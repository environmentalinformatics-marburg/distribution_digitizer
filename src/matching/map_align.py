# ============================================================
# File: map_align.py
# Author: Spaska Forteva
# Last modified on: 2024-03-13 by Spaska Forteva
#
# Description:
# This script performs geometric alignment of extracted map images
# using feature-based image matching.
#
# It uses ORB (Oriented FAST and Rotated BRIEF) keypoints to detect
# corresponding features between an input image and a reference template.
# A homography transformation is then computed to align the input map
# to the template coordinate system.
#
# The script processes multiple map types and ensures that all extracted
# maps are spatially consistent, which is a crucial prerequisite for
# downstream steps such as point detection and georeferencing.
# ============================================================

# ------------------------------------------------------------
# Import required libraries
# ------------------------------------------------------------
# OpenCV (cv2): feature detection, matching, homography, warping
# PIL: image loading and saving
# numpy: numerical operations
# imutils: image resizing for debugging visualization
# glob/os: file system handling
# ------------------------------------------------------------

import PIL
import numpy as np
import imutils
import cv2
import os
import glob
from PIL import Image

# ------------------------------------------------------------
# Align a single image to a reference template
# ------------------------------------------------------------
# Core idea:
# Detect feature correspondences between the input image and a
# reference template, then compute a homography transformation
# to geometrically align the image.
#
# Key steps:
# - Convert images to grayscale
# - Detect ORB keypoints and descriptors
# - Match descriptors using brute-force Hamming distance
# - Keep only the best matches (based on distance ranking)
# - Compute homography using RANSAC (robust to outliers)
# - Warp the input image into template space
#
# Important design decisions:
# - ORB is used because it is fast and does not require licensing
# - Only a percentage of best matches is kept to reduce noise
# - RANSAC ensures robustness against incorrect matches
#
# Output:
# - Aligned image saved to output directory
#
# Returns:
# - True if alignment succeeded
# - False if matching or homography fails
# ------------------------------------------------------------
def align_images(image_path, template, template_gray, output_dir, max_features=500, keep_percent=0.2, debug=False):
    """
    Align images using ORB features and homography.

    Args:
    - image_path (str): Path to the input image.
    - template_path (str): Path to the template image.
    - output_dir (str): Output directory for aligned images.
    - max_features (int): Maximum number of features to detect with ORB.
    - keep_percent (float): Percentage of top features to keep.
    - debug (bool): Flag to enable visualization of matched keypoints.

    Returns:
    - bool: True for success, False for error.
    """
    try:
        image = np.array(PIL.Image.open(image_path))
        #template = np.array(PIL.Image.open(template_path))
        image_gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        #template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
        
        # Detect keypoints and compute descriptors using ORB (fast and robust)
        orb = cv2.ORB_create(max_features)
        (keypoints_image, descriptors_image) = orb.detectAndCompute(image_gray, None)
        (keypoints_template, descriptors_template) = orb.detectAndCompute(template_gray, None)
        
        # Match descriptors using brute-force Hamming distance
        method = cv2.DESCRIPTOR_MATCHER_BRUTEFORCE_HAMMING
        matcher = cv2.DescriptorMatcher_create(method)
        matches = matcher.match(descriptors_image, descriptors_template, None)
        
        if len(matches) < 4:
          print("⚠️ Not enough matches for reliable homography")
          return False
  
        matches = sorted(matches, key=lambda x: x.distance)
        keep = int(len(matches) * keep_percent)
        matches = matches[:keep]

        if debug:
            matched_vis = cv2.drawMatches(image, keypoints_image, template, keypoints_template, matches, None)
            matched_vis = imutils.resize(matched_vis, width=1000)
            cv2.imshow("Matched Keypoints", matched_vis)
            cv2.waitKey(0)

        points_image = np.zeros((len(matches), 2), dtype="float")
        points_template = np.zeros((len(matches), 2), dtype="float")

        for (i, match) in enumerate(matches):
            points_image[i] = keypoints_image[match.queryIdx].pt
            points_template[i] = keypoints_template[match.trainIdx].pt

        (homography_matrix, _) = cv2.findHomography(points_image, points_template, method=cv2.RANSAC)
        if homography_matrix is None:
          print("⚠️ Homography could not be computed")
          return False
        
        (height, width) = template.shape[:2]
        # Warp input image to align with template coordinate system
        aligned = cv2.warpPerspective(image, homography_matrix, (width, height))

        PIL.Image.fromarray(aligned).save(os.path.join(output_dir, os.path.basename(image_path)))

        return True  # Success

    except Exception as e:
        print("An error occurred in align_images:", e)
        return False  # Error


# ------------------------------------------------------------
# Batch alignment for all map types
# ------------------------------------------------------------
# This function iterates over all map types and aligns each
# extracted map image to a corresponding reference template.
#
# Workflow:
# - Loop over map type folders (1, 2, 3, ...)
# - Load reference templates for alignment
# - Load previously extracted maps (matching results)
# - Clean output directory to avoid mixing old and new results
# - Align each map image using the align_images() function
#
# Key design decisions:
# - Only one reference template per map type is used
#   (ensures consistency across all maps of the same type)
# - Output directory is cleaned before processing
#   (prevents outdated or incorrect results)
#
# Output:
# - Aligned map images stored in:
#   output/<type>/maps/align/
#
# Returns:
# - True if processing completed
# - False if an error occurred
# ------------------------------------------------------------
def align_images_directory(working_dir, outDir, nMapTypes=1):
    """
    Aligns matched maps for each map type (1, 2, 3, ...).

    Expected structure:
      data/input/templates/<type>/align_ref/
      <outDir>/<type>/maps/matching/
      <outDir>/<type>/maps/align/
    """
    try:
        working_dir = working_dir.rstrip("/\\")
        outDir = outDir.rstrip("/\\")
        print(f"➡️ Starting alignment for {nMapTypes} map type(s)...")

        for i in range(1, int(nMapTypes) + 1):
            type_id = str(i)
            #print(f"\n🔧 Processing map type {type_id}")

            template_dir = os.path.join(working_dir, "data", "input", "templates", type_id, "align_ref")
            input_dir = os.path.join(outDir, type_id, "maps", "matching")
            output_dir = os.path.join(outDir, type_id, "maps", "align")

            # ------------------------------------------------------------
            # Validate output directory (must exist) AND clean it
            # ------------------------------------------------------------
            if not os.path.isdir(output_dir):
                #print(f"❌ Output directory does not exist (configuration error): {output_dir}")
                #print("❌ Alignment aborted for this map type.")
                continue
            
            # Clean output directory to remove results from previous runs
            old_files = glob.glob(os.path.join(output_dir, "*.tif"))
            
            if old_files:
                print(f"🧹 Cleaning output directory ({len(old_files)} old files)")
                for f in old_files:
                    try:
                        os.remove(f)
                    except Exception as e:
                        print(f"⚠️ Could not remove {f}: {e}")
            else:
                print("ℹ️ Output directory already clean")

            # Skip missing dirs gracefully
            if not os.path.isdir(template_dir):
                #print(f"⚠️ Missing template folder for type {type_id}: {template_dir}")
                continue
            if not os.path.isdir(input_dir):
                #print(f"⚠️ Missing input folder for type {type_id}: {input_dir}")
                continue

            template_files = sorted(glob.glob(os.path.join(template_dir, "*.tif")))
            image_files = sorted(glob.glob(os.path.join(input_dir, "*.tif")))

            if not template_files:
                #print(f"⚠️ No templates found in {template_dir}")
                continue
            if not image_files:
                #print(f"⚠️ No maps to align in {input_dir}")
                continue

            # --- Für jeden Kartentyp nur den besten Referenz-Template nehmen ---
            best_template = template_files[0]  # ggf. nur eine Referenz vorhanden
            print(f"🧭 Using reference template: {os.path.basename(best_template)}")
            
            # Load template once → improves performance significantly
            best_template_img = np.array(PIL.Image.open(best_template))
            best_template_gray = cv2.cvtColor(best_template_img, cv2.COLOR_BGR2GRAY)
            
            for image_path in image_files:
                #print(f"  🖼️ Aligning {os.path.basename(image_path)} → {type_id}")
   
                success = align_images(
                          image_path,
                          best_template_img,
                          best_template_gray,
                          output_dir
                      )
                if not success:
                    print(f"❌ Failed to align {os.path.basename(image_path)}")

        print("\n✅ Alignment completed for all map types.")
        return True

    except Exception as e:
        print("❌ An error occurred in align_images_directory:", e)
        return False
