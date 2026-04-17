def match_template(previous_page_path, next_page_path, current_page_path,
                   template_map_files, output_dir, output_page_records,
                   records, threshold, page_position, map_group="1"):

    try:
        print("🗺️ Page:", current_page_path)
        start_time = time.time()

        img = np.array(Image.open(current_page_path))
        imgc = img.copy()
        img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        page_number = find_page_number(current_page_path, page_position)

        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(output_page_records, exist_ok=True)

        count = 0

        # ============================================================
        # 🔥 1. COLLECT ALL CANDIDATES (ALL TEMPLATES)
        # ============================================================
        all_candidates = []

        for template_map_file, tmp in template_map_files:
            print("📌 Template:", template_map_file)

            h, w, _ = tmp.shape
            tmp_gray = cv2.cvtColor(tmp, cv2.COLOR_BGR2GRAY)

            res = cv2.matchTemplate(img_gray, tmp_gray, cv2.TM_CCOEFF_NORMED)
            loc = np.where(res >= threshold)

            for (x, y) in zip(loc[1], loc[0]):
                score = float(res[y, x])
                all_candidates.append((x, y, score, w, h, template_map_file))

        if not all_candidates:
            print("⚠️ No candidates found.")
            return

        # ============================================================
        # 🔥 2. SORT GLOBAL BY SCORE (BEST FIRST)
        # ============================================================
        all_candidates.sort(key=lambda z: z[2], reverse=True)

        # ============================================================
        # 🔥 3. IoU FILTER (KEEP ONLY BEST PER REGION)
        # ============================================================
        final_matches = []

        def iou(boxA, boxB):
            xA = max(boxA[0], boxB[0])
            yA = max(boxA[1], boxB[1])
            xB = min(boxA[0]+boxA[2], boxB[0]+boxB[2])
            yB = min(boxA[1]+boxA[3], boxB[1]+boxB[3])

            inter = max(0, xB-xA) * max(0, yB-yA)
            areaA = boxA[2]*boxA[3]
            areaB = boxB[2]*boxB[3]

            return inter / (areaA + areaB - inter + 1e-6)

        for cand in all_candidates:
            x, y, score, w, h, template_map_file = cand
            box = (x, y, w, h)

            keep = True
            for kept in final_matches:
                kx, ky, ks, kw, kh, _ = kept
                if iou(box, (kx, ky, kw, kh)) > 0.5:
                    keep = False
                    break

            if keep:
                final_matches.append(cand)

        print(f"✅ Final matches: {len(final_matches)}")

        # ============================================================
        # 🔥 4. SAVE RESULTS
        # ============================================================
        for (x, y, score, w, h, template_map_file) in final_matches:

            size = w * h * (2.54 / 400) ** 2
            threshold_last = str(threshold).split(".")[-1]

            base_name = (
                f"{page_number}-thr{threshold_last}_"
                f"{os.path.basename(current_page_path).rsplit('.', 1)[0]}_"
                f"{os.path.basename(template_map_file).rsplit('.', 1)[0]}_"
                f"y{y}_x{x}_n{count}"
            )

            img_save_path = os.path.join(output_dir, base_name + ".tif")
            csv_save_path = os.path.join(output_page_records, base_name + ".csv")

            extra_h = int(h * 0.1)
            y_end = min(y + h + extra_h, imgc.shape[0])
            crop = imgc[y:y_end, x:x + w, :]

            cv2.imwrite(img_save_path, crop)

            record_row = [
                page_number,
                previous_page_path,
                next_page_path,
                current_page_path,
                img_save_path,
                x, y, w, h,
                size,
                threshold,
                round(time.time() - start_time, 3),
                map_group
            ]

            is_empty = not os.path.exists(records) or os.stat(records).st_size == 0
            with open(records, 'a', newline='') as csv_file:
                writer = csv.writer(csv_file)
                if is_empty:
                    writer.writerow(fields_page_record)
                writer.writerow(record_row)

            with open(csv_save_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(fields_page_record)
                writer.writerow(record_row)

            count += 1

    except Exception as e:
        print("❌ Error in match_template:", e)
