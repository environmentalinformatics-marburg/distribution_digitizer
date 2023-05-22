import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time
import os

start_time = time.time()

# field names for the records csv files 
fields = ['filename', 'x', 'y', 'w', 'h', 'size','threshold','time']

# field names for the page records csv files 
fieldsPageRecords = ['filename', 'mapname', 'x', 'y', 'w', 'h', 'size','threshold','time']   

# Tests
#Batch Processing
#threshold= float(input('Enter the threshold value or Press Enter for 0.2 ')or 0.2)
#temp = str(input('Enter the Template Directory /.../'))
#Input = str(input('Enter the Input Directory /.../'))
#records =str(input('Enter the Record Directory /.. .csv'))
#outdir = str(input('Enter directory for output /.../'))
#print("Entered threshold value",threshold) 
#workingDir = "D:/distribution_digitizer/"
#mainTemplateMatching(workingDir, 0.99)


    
# Function matchtemplatetiff 
# find the maps, save this and write the map coordinats in a csv file
def matchtemplatetiff(tifffile, templateMapfile, outdir, 
          outputpagerecords, records, threshold):
  
  print(tifffile)
  print(templateMapfile)
  
  # user the PIL library to open the tiffile
  img = np.array(PIL.Image.open(tifffile))
  imgc = img.copy()
   
   # user the PIL library to open the template map
  tmp = np.array(PIL.Image.open(templateMapfile))
  # read the width and heigth from template maps
  h, w, c = tmp.shape 

  # Template Matching Function from package cv2
  res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
  # Adjust this threshold value to suit you, you may need some trial runs (critical!)
  loc = np.where(res >= threshold)
  
  # define an empty lists to store a range from X and Y coordinates
  lspointY = []
  lspointX = []
  
  count = 0
  font = cv2.FONT_HERSHEY_SIMPLEX
  for pt in zip(*loc[::-1]):
        # check that the coords are not already in the list, if they are then skip the match
        if pt[0] not in lspointY and pt[1] not in lspointX:
          
            # draw a yellow boundary around a match- USE this just for tests!
            #rect = cv2.rectangle(img, pt, (pt[0] + h, pt[1] + w), (0, 0, 0), 3)
            size = w * h * (2.54/400 ) *( 2.54/400 )
            
            # put text with the information values - USE this just for tests!
            #cv2.putText(rect, "{:.1f}cm^2".format(size), (pt[0] + h, pt[1] + w), font, 4,0, 0, 255), 3)
            #cv2.imwrite('rect.png',rect)
            
            # data rows of csv file   
            rows = 0
            rows = [[tifffile, pt[0], pt[1], w, h ,size, threshold, (time.time() - start_time)]]   
            # print(outdir) 
            threshold_last=str(threshold).split(".")
            # print(threshold_last[1])
            
            imgMapPath = (str(threshold_last[1]) + '_' +
            os.path.basename(tifffile).rsplit('.', 1)[0] + 
            os.path.basename(templateMapfile).rsplit('.', 1)[0] + '_' + str(count))
            
            cv2.imwrite(outdir + imgMapPath + '.tif', imgc[ pt[1]:(pt[1] + h), pt[0]:(pt[0] + w),:])
            
            # WRITE the fields and rows values into the main records csv file
            with open(records, 'a', newline='') as csvfile:  
              # creating a csv writer object   
              csvwriter = csv.writer(csvfile) 
              #if count == 0: 
              csvwriter.writerow(fields)
              ## writing the rows
              csvwriter.writerows(rows)
            
            # WRITE the fields and rows values into the page record csv file
            rows = [[tifffile, outdir + imgMapPath + '.tif', pt[0], pt[1], 
              w, h ,size, threshold, (time.time() - start_time)]]  
            csvPath = outputpagerecords + imgMapPath + '.csv'
            with open(csvPath, 'w', newline='') as pageRecord:  
              ## creating a csv writer object   
              pageCsvwriter = csv.writer(pageRecord)  
              pageCsvwriter.writerow(fieldsPageRecords)
              ## writing the rows
              pageCsvwriter.writerows(rows)
                  
            ## append a range from first y coord to x + width
            for k in range((pt[1]), ((pt[1])+h), 1):
			          lspointX.append(k)
            ## append a range from first y coord to y + high
            for i in range((pt[0]), ((pt[0])+w), 1):
                lspointY.append(i)
            count += 1
        else:
            continue
    
  print(templateMapfile)
  print(tifffile)
  print("--- %s seconds ---" % (time.time() - start_time))
  PIL.Image.fromarray(img, 'RGB').save(os.path.join(tifffile))




# Function mainTemplateMatching - start the mathching in loop 
def mainTemplateMatching(workingDir, threshold):
    
  # OUTPUT
  outdir = workingDir + "/data/output/maps/matching/"
  os.makedirs(outdir, exist_ok=True)
  # classifikation csv file
  #outputpcdirClassifikation = workingDir + "/classification/matching/"
  #os.makedirs(outputpcdirClassifikation, exist_ok=True)

  # pagerecords csv file with the map coordinats
  outputpagerecords = workingDir + "/data/output/pagerecords/"
  os.makedirs(outputpagerecords, exist_ok=True)
  # files = glob.glob(outputpagerecords)
  #for f in files:
    #os.remove(f)
  records = workingDir + "/data/output/records.csv"
  # input dirs
  templates = workingDir+"/data/input/templates/maps/"
  inputdir = workingDir + "/data/input/pages/"
  
  
  # start the matching in loop input templates and input pages 
  with open(records, 'w', newline='') as csvfile:  
    
    # creating a csv writer object to write the map coordinats     
    csvwriter = csv.writer(csvfile)   
      
    for templateMapfile in glob.glob(templates + '*.tif'): 
      for tifffile in glob.glob(inputdir +'*.tif'): 
        matchtemplatetiff(tifffile, templateMapfile, outdir, 
          outputpagerecords, records, threshold)

            



