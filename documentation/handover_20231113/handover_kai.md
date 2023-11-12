**Handover**

Author: Kai Richter
Date: 2023-11-13

*Explanations of work packages done by Kai from July to November 2023* 

########################################################################

Between June and November 2023, I completed the following main tasks:
1. Fixing the polygonizing step (~ Jul 2023)
2. Implementing "Circle Detection" method (~ Aug-Sep 2023)
3. Implementing centroid extraction of detected symbols and creating long-format csv file (~ Sep-Nov 2023)

In the following, explanations for all four work packages will be given.

For all added and modified scripts listed, detailed explanations and comments addressing the sub-steps for the of each script
are inserted in the respective script files. 

#---------------------------------------------------------------------------

*** 1. Fixing the polygonizing step ***

scripts added: 
- src/polygonize/rectifying.py

scripts modified: 
- src/polygonize/polygonize.py

Description:
After the georeferencing, the edges of the output files are warped and not straight, which is why the bounding box is not
taken over correctly by the 'polygonize' function. To address this issue, the function 'rectifying' is called after 
georeferencing and before polygonizing to rectify the tif files. In this step, the edges are filled with pixels of the 
value "0". It is important that the output of the 'masking_black' folder is used. Otherwise, the values of appended pixels
and the masked background do not match. 
The paths of the functions contained in the script polygonize.py have been adjusted.
The script rectifying.py has been binded into the app.R script.

*status:* FINISHED

#---------------------------------------------------------------------------

*** 2. Implementing "Circle Detection" method ***

scripts added: 
- src/matching/circle_detection.py

Description:
The Template Matching and Point Filtering method did not work well for maps containing overlapping symbols and differences
among symbol types. The Circle Detection method provides a third approach (so far) for detecting a variety of circle symbols 
on the same map and addresses the issue of overlapping symbols (at least for circles). 
The script circle_detection.py has been binded into the app.R script.

*status:* FINISHED

#----------------------------------------------------------------------------

*** 3. Implementing centroid extraction of detected symbols and creating long-format csv file ***

scripts modified:
- src/matching/circle_detection.py
- src/matching/point_filtering.py
- src/georeferencing/mask_georeferencing.py
- src/polygonize/polygonize.py
- src/polygonize/rectifying.py

scripts added:
- src/masking/mask_centroids.py
- src/extract_coordinates/poly_to_point.py
- src/georeferencing/centroid_georeferencing.py
- src/matching/coords_to_csv.py

Description: 
First approach: For extracting the centroids of detected symbols, it is better to directly mask the centroid pixels on the 
maps instead of masking the symbols. For that, the functions of the scripts circle_detection.py and point_filtering.py have 
supplemented that the centroid pixels of detected symbols are marked red. 
After that, the script mask_centroids.py masks the marked centroids pixels and stores the results in seperate folders for
centroids detected by respectively Circle Detection and Point Filtering method. 
The further steps Georeferencing and Polygonize are then processed with the functions already implemented. The scripts for 
Georeferencing and Polygonizing (mask_georeferencing.py, rectifying.py, polygonize.py) have been appended by new main-functions
for storing the outputs of Circle-Detection-centroids and Point-Filtering-centroids in seperate folders.
The added main-functions as well as the script mask_centroids.py have been binded into the app.R script. 
As last step, the polygonized centroids pixels have to be converted to point-shapefiles and the coordinates should be stored
in a csv file. The script poly_to_point.py creates point-shapefiles. It remains to be binded into the UI (app.R)!

A second approach for extracting the centroid coordinates was to directly store the detected original coordinates in a csv file
and georeference them mathematically. In the functions 'mainCircleDetection' (circle_detection.py) and 'mainPointFiltering'
(point_filtering.py), the functions contained in the script coords_to_csv.py are called to initialize and append a csv file.
The script centroid_georeferencing.py georeferences them mathematically. The script is binded into the app.R script (menuItem 5.2).
However, the coordinates of centroids on the georeferenced maps and the respective mathematically georeferenced coordinates in 
the csv file do not match (Offset of 10-20 km). 
I suggest to not prioritize this approach and focus on the first approach in the future. 

*status:* 
- source code is almost finished (the coordinate extraction of point-shapefiles and storage in a long-format csv file remains to
  be written)
- binding final steps into UI has still to be done

*next steps to do:*
- Binding the script poly_to_point.py into the shiny UI (app.R). I suggest to create a new menuItem for that 
  (e.g. '7. Extraction of centroid coordinates').
- Write a script for extracting the coordinates of the point-shapefiles and store them into a long-format csv file 
  (The script src/matching/coords_to_csv.py may provide a well-suited template to build up on)
- Implement "List Files" buttons for the new created results obtained by running the new functions of the scripts 
  mask_georeferencing.py, rectifying.py, polygonize.py in the menuItems '4. Masking', '5. Georeferencing', '6. Polygonizing'.
  This would provide consistency among the workflow steps framed in the UI. 

#----------------------------------------------------------------------------

*** Things to be optimized later *** 
- revise paths that are displayed in the UI and the alert messages (not all of them are correct!)
- 