def read_page_number_region(
    image_path,
    x_relative,
    y_relative,
    width_relative,
    height_relative,
    tesseract_cmd=None
):
    """
    Read text from a user-selected page-number region.

    The region coordinates are relative to the complete page image.
    OCR is performed on the original-resolution image.
    """

    import cv2
    import pytesseract

    if tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    # ---------------------------------------------------------
    # Load original page
    # ---------------------------------------------------------

    image = cv2.imread(image_path)

    if image is None:
        raise ValueError(
            f"Could not read image: {image_path}"
        )

    image_height, image_width = image.shape[:2]

    # ---------------------------------------------------------
    # Convert relative coordinates to original pixels
    # ---------------------------------------------------------

    x = int(round(x_relative * image_width))
    y = int(round(y_relative * image_height))

    width = int(round(width_relative * image_width))
    height = int(round(height_relative * image_height))

    x2 = min(x + width, image_width)
    y2 = min(y + height, image_height)

    x = max(0, x)
    y = max(0, y)

    crop = image[y:y2, x:x2]

    if crop.size == 0:
        raise ValueError(
            "Selected page-number region is empty."
        )

    # ---------------------------------------------------------
    # Prepare image for OCR
    # ---------------------------------------------------------

    gray = cv2.cvtColor(
        crop,
        cv2.COLOR_BGR2GRAY
    )

    # enlarge small page numbers
    gray = cv2.resize(
        gray,
        None,
        fx=3,
        fy=3,
        interpolation=cv2.INTER_CUBIC
    )

    # ---------------------------------------------------------
    # OCR
    # ---------------------------------------------------------

    text = pytesseract.image_to_string(
        gray,
        config="--psm 7"
    )

    return text.strip()
