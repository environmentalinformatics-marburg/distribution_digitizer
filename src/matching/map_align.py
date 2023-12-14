import PIL
import numpy as np
import imutils
import cv2
import os
import glob
from PIL import Image

__author__ = "Spaska Forteva"
__date__ = "2022-12-14"
__change_date__ = "2023-12-15"

def align_images(image_path, template_path, output_dir, max_features=500, keep_percent=0.2, debug=False):
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
        template = np.array(PIL.Image.open(template_path))
        image_gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)

        orb = cv2.ORB_create(max_features)
        (keypoints_image, descriptors_image) = orb.detectAndCompute(image_gray, None)
        (keypoints_template, descriptors_template) = orb.detectAndCompute(template_gray, None)

        method = cv2.DESCRIPTOR_MATCHER_BRUTEFORCE_HAMMING
        matcher = cv2.DescriptorMatcher_create(method)
        matches = matcher.match(descriptors_image, descriptors_template, None)

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

        (height, width) = template.shape[:2]
        aligned = cv2.warpPerspective(image, homography_matrix, (width, height))

        PIL.Image.fromarray(aligned).save(os.path.join(output_dir, os.path.basename(image_path)))

        return True  # Success

    except Exception as e:
        print(f"Error: {e}")
        return False  # Error


def align_images_directory(working_dir):
    """
    Aligns images in the specified working directory.

    Args:
    - working_dir (str): Working directory containing input images.

    Returns:
    - None
    """
    # Output directory for aligned images
    output_dir = working_dir + "/data/output/maps/align/"
    os.makedirs(output_dir, exist_ok=True)

    # Directory for template images
    template_dir = working_dir + "/data/input/templates/align_ref/"

    # Directory for input images
    input_dir = working_dir + "/data/output/maps/matching/"

    # Directory for converted PNG images after the matching process
    output_png_dir = working_dir + "/www/align_png/"
    os.makedirs(output_png_dir, exist_ok=True)

    for template_path in glob.glob(template_dir + '*.tif'):
        for image_path in glob.glob(input_dir + '*.tif'):
            print(image_path)
            success = align_images(image_path, template_path, output_dir)
            if not success:
                return False  # Exit the loop if there's an error

    return True  # Success
