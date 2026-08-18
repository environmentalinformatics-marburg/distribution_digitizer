import cv2
import pytesseract


def read_training_region(
    image_path,
    x_relative,
    y_relative,
    width_relative,
    height_relative
):
    """
    Read the text inside a user-confirmed species title region.

    Relative coordinates originate from the Shiny preview and
    are converted to coordinates of the original TIFF image.
    """

    image = cv2.imread(image_path)

    if image is None:
        return ""

    image_height, image_width = image.shape[:2]

    # Convert relative coordinates to original TIFF coordinates
    x = int(round(x_relative * image_width))
    y = int(round(y_relative * image_height))

    width = int(round(width_relative * image_width))
    height = int(round(height_relative * image_height))

    x2 = min(x + width, image_width)
    y2 = min(y + height, image_height)

    # Crop title region
    crop = image[y:y2, x:x2]

    if crop.size == 0:
        return ""

    # Slight enlargement helps OCR with small printed text
    crop = cv2.resize(
        crop,
        None,
        fx=3,
        fy=3,
        interpolation=cv2.INTER_CUBIC
    )

    gray = cv2.cvtColor(
        crop,
        cv2.COLOR_BGR2GRAY
    )

    # OCR: selected region normally contains one title line
    text = pytesseract.image_to_string(
        gray,
        config="--psm 7"
    )

    return text.strip()
