import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time

start_time = time.time()

# field names   
fields = ['Filename','w', 'h', 'x2', 'y2', 'size','threshold','time']   

#Function
def matchtemplatetiff(tifffile, file, outdir, outputpcdir, records, threshold):
    print(tifffile)
    print(file)
    img =np.array(PIL.Image.open(tifffile))
    tmp= np.array(PIL.Image.open(file))
    imgc=img.copy()
    w, h, c = tmp.shape
    
    #Template Matching Function
    res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
    
    # Adjust this threshold value to suit you, you may need some trial runs (critical!)
    loc = np.where(res >= threshold)
    
    # Important!
    # define an empty list in which a range from coordinates is stored. The width/hight of the map is dynamically defined as max
    lspointX = []
    lspointY =[]
    
    count = 0
    font = cv2.FONT_HERSHEY_SIMPLEX
    n=0
    m=0
    for pt in zip(*loc[::-1]):
          # check that the coords are not already in the list, if they are then skip the match
          if pt[0] not in lspointX and pt[1] not in lspointY:
              # draw a yellow boundary around a match
              #rect = cv2.rectangle(img, pt, (pt[0] + h, pt[1] + w), (0, 0, 0), 3)
              size = w * h * (2.54/400 ) *( 2.54/400 )
              #cv2.putText(rect, "{:.1f}cm^2".format(size), (pt[0] + h, pt[1] + w), font, 4,0, 0, 255), 3)
              #cv2.imwrite('rect.png',rect)
              # data rows of csv file   
              rows = 0
              rows = [[tifffile, w, h , pt[1] + w, pt[0] + h, size, threshold, (time.time() - start_time)]]   
              print(outdir) 
              threshold_last=str(threshold).split(".")
              print(threshold_last[1])
              cv2.imwrite(outdir + str(threshold_last[1]) + '_' +os.path.basename(tifffile).rsplit('.', 1)[0] + os.path.basename(file).rsplit('.', 1)[0] + '_' + str(n)+ '.tif', imgc[ pt[1]:(pt[1] + w), pt[0]:(pt[0] + h),:])
              cv2.imwrite(outputpcdir + str(threshold_last[1]) + '_' + os.path.basename(tifffile).rsplit('.', 1)[0] + os.path.basename(file).rsplit('.', 1)[0] + '_' + str(n)+ '.tif', imgc[ pt[1]:(pt[1] + w), pt[0]:(pt[0] + h),:])
              #cv2.imwrite(tifffile + file.rsplit('.', 1)[0] + str(n)+ '.tif', imgc[ pt[1]:(pt[1] + w), pt[0]:(pt[0] + h),:])
              # name of csv file   
              filename = records
              # writing to csv file   
              with open(filename, 'a', newline='') as csvfile:   
                 # creating a csv writer object   
                 csvwriter = csv.writer(csvfile)   
                 # writing the fields   
                 csvwriter.writerow(fields)   
                 # writing the data rows   
                 csvwriter.writerows(rows)
              for i in range((pt[0]), ((pt[0])+h), 1):
  		          	## append the y possible cooords in range high
                  lspointY.append(i)
              for k in range((pt[1]), ((pt[1])+w), 1):
  			          ## append the x possible coords in range width
                  lspointX.append(k)
              count+=1
              n=n+1
          else:
              m=m+1
              continue
      
    print(file)
    print(tifffile)
    print("--- %s seconds ---" % (time.time() - start_time))
    m=m+1
    PIL.Image.fromarray(img, 'RGB').save(os.path.join(tifffile))

#Batch Processing
#threshold= float(input('Enter the threshold value or Press Enter for 0.2 ')or 0.2)
#temp = str(input('Enter the Template Directory /.../'))
#Input = str(input('Enter the Input Directory /.../'))
#records =str(input('Enter the Record Directory /.. .csv'))
#outdir = str(input('Enter directory for output /.../'))
#print("Entered threshold value",threshold) 

def mainTemplateMatching(workingDir, threshold):
    outputpcdir = workingDir + "/data/output/classification/matching/"
    os.makedirs(outputpcdir, exist_ok=True)
    templates = workingDir+"/data/templates/maps/"
    inputdir = workingDir + "/data/input/"
    outdir = workingDir + "/data/output/"
    records = workingDir + "/data/output/records.csv"
    print("g)")
    for file in glob.glob(templates + '*.tif'): 
        for tifffile in glob.glob(inputdir +'*.tif'): 
            matchtemplatetiff(tifffile, file, outdir, outputpcdir, records, threshold)
  
  
  
#workingDir = "D:/distribution_digitizer/"
#mainTemplateMatching(workingDir, 0.99)


