# Author: Spaska Forteva
# Description: Point matching for distribution maps

import cv2
import os
import glob
import numpy as np
import csv
import shutil


COLOR_MAP = {
    "red": "#FF0000",
    "green": "#00FF00",
    "blue": "#0000FF",
    "yellow": "#FFFF00",
    "orange": "#FFA500",
    "magenta": "#FF00FF"
}


def copy_tiff_images(input_dir, output_dir):

    os.makedirs(output_dir, exist_ok=True)

    for file in os.listdir(input_dir):
        if file.endswith(".tif"):
            shutil.copyfile(
                os.path.join(input_dir, file),
                os.path.join(output_dir, file)
            )


def non_max_suppression_fast(points, overlapThresh):

    if len(points) == 0:
        return []

    if points.dtype.kind == "i":
        points = points.astype("float")

    pick = []

    x1 = points[:,0]
    y1 = points[:,1]
    x2 = x1 + points[:,2]
    y2 = y1 + points[:,3]

    area = (x2-x1+1)*(y2-y1+1)

    idxs = np.argsort(y2)

    while len(idxs) > 0:

        last = len(idxs)-1
        i = idxs[last]

        pick.append(i)

        xx1 = np.maximum(x1[i], x1[idxs[:last]])
        yy1 = np.maximum(y1[i], y1[idxs[:last]])
        xx2 = np.minimum(x2[i], x2[idxs[:last]])
        yy2 = np.minimum(y2[i], y2[idxs[:last]])

        w = np.maximum(0, xx2-xx1+1)
        h = np.maximum(0, yy2-yy1+1)

        overlap = (w*h)/area[idxs[:last]]

        idxs = np.delete(
            idxs,
            np.concatenate(([last], np.where(overlap>overlapThresh)[0]))
        )

    return points[pick].astype("int")


def hex_to_rgb(hex_color):

    hex_color = hex_color.lstrip('#')

    return tuple(
        int(hex_color[i:i+2],16) for i in (0,2,4)
    )


def point_match(img_color, template_path, threshold, template_name, color, coord_writer, current_id, used_points):

    img_gray = cv2.cvtColor(img_color, cv2.COLOR_BGR2GRAY)

    tmp_gray = cv2.imread(template_path, cv2.IMREAD_GRAYSCALE)

    h,w = tmp_gray.shape[:2]

    res = cv2.matchTemplate(img_gray, tmp_gray, cv2.TM_CCOEFF_NORMED)

    loc = np.where(res >= threshold)

    points = []

    for pt in zip(*loc[::-1]):
        points.append([pt[0], pt[1], w, h])

    points = np.array(points)

    nms_points = non_max_suppression_fast(points,0.3)

    red,green,blue = hex_to_rgb(color)

    detected = 0

    for (x,y,w,h) in nms_points:

        center_x = x + w//2
        center_y = y + h//2

        score = res[y,x]

        skip=False
        replace_index=-1

        for i,(px,py,ps) in enumerate(used_points):

            if abs(center_x-px)<10 and abs(center_y-py)<10:

                if score>ps:
                    replace_index=i
                else:
                    skip=True

                break

        if skip:
            continue

        if replace_index>=0:
            used_points[replace_index]=(center_x,center_y,score)
        else:
            used_points.append((center_x,center_y,score))

        radius=min(w,h)//4

        cv2.circle(img_color,(center_x,center_y),radius,(blue,green,red),-1)

        coord_writer.writerow({
            "ID":current_id,
            "File":"",
            "Detection method":"point_matching",
            "X_WGS84":center_x,
            "Y_WGS84":center_y,
            "template":template_name,
            "Red":red,
            "Green":green,
            "Blue":blue,
            "georef":0
        })

        current_id+=1
        detected+=1

    return img_color,detected,current_id


def map_points_matching(workingDir,outDir,threshold,nMapTypes=1):

    print("Points matching")

    map_type_dirs=[]

    for name in os.listdir(outDir):

        full=os.path.join(outDir,name)

        if os.path.isdir(full) and name.isdigit():
            map_type_dirs.append(full)

    map_type_dirs = map_type_dirs[:int(nMapTypes)]

    for map_dir in map_type_dirs:

        map_type=os.path.basename(map_dir)

        print("Processing map type:",map_type)

        pointTemplates=os.path.join(
            workingDir,
            "data","input","templates",
            map_type,
            "symbols"
        )

        inputTiffDir=os.path.join(map_dir,"maps","align")
        outputTiffDir=os.path.join(map_dir,"maps","pointMatching")
        csvDir=os.path.join(map_dir,"maps","csvFiles")

        os.makedirs(outputTiffDir,exist_ok=True)
        os.makedirs(csvDir,exist_ok=True)

        copy_tiff_images(inputTiffDir,outputTiffDir)

        coord_csv_path=os.path.join(csvDir,"coordinates.csv")

        with open(coord_csv_path,"a",newline="") as coord_csvfile:

            coord_fieldnames=[
                "ID","File","Detection method",
                "X_WGS84","Y_WGS84","template",
                "Red","Green","Blue","georef"
            ]

            coord_writer=csv.DictWriter(coord_csvfile,fieldnames=coord_fieldnames)

            if coord_csvfile.tell()==0:
                coord_writer.writeheader()

            current_id=1

            for tiffile in glob.glob(os.path.join(outputTiffDir,"*.tif")):

                print("Processing map:",tiffile)

                img_color=cv2.imread(tiffile)

                used_points=[]

                color_counts={
                    "red":0,
                    "blue":0,
                    "green":0,
                    "yellow":0,
                    "orange":0,
                    "magenta":0
                }

                for file in glob.glob(os.path.join(pointTemplates,"*.tif")):

                    template_name=os.path.basename(file).rsplit(".",1)[0]

                    color_name=template_name.split("_")[0].lower()

                    color=COLOR_MAP.get(color_name,"#FFFFFF")

                    img_color,num_points,current_id = point_match(
                        img_color,
                        file,
                        threshold,
                        template_name,
                        color,
                        coord_writer,
                        current_id,
                        used_points
                    )

                    if color_name in color_counts:
                        color_counts[color_name]+=num_points

                name_part="_".join(
                    [f"{c}{n}" for c,n in color_counts.items() if n>0]
                )

                base=os.path.basename(tiffile).replace(".tif","")

                new_name=f"{base}_{name_part}.tif"

                cv2.imwrite(
                    os.path.join(outputTiffDir,new_name),
                    img_color
                )

                os.remove(tiffile)

    print("✓ Point matching completed")
