
import PIL
import numpy as np
import imutils
import cv2
import os
import glob
from PIL import Image

def align_images(image, template, outputdir,maxFeatures=500, keepPercent=0.2,
	debug=False):
	# convert both the input image and template to grayscale
	image1 = np.array(PIL.Image.open(image))
	template1 = np.array(PIL.Image.open(template))
	imageGray = cv2.cvtColor(image1, cv2.COLOR_BGR2GRAY)
	templateGray = cv2.cvtColor(template1, cv2.COLOR_BGR2GRAY)
	# use ORB to detect keypoints and extract (binary) local
	# invariant features
	orb = cv2.ORB_create(maxFeatures)
	(kpsA, descsA) = orb.detectAndCompute(imageGray, None)
	(kpsB, descsB) = orb.detectAndCompute(templateGray, None)
	# match the features
	method = cv2.DESCRIPTOR_MATCHER_BRUTEFORCE_HAMMING
	matcher = cv2.DescriptorMatcher_create(method)
	matches = matcher.match(descsA, descsB, None)
	# sort the matches by their distance (the smaller the distance,
	# the "more similar" the features are)
	matches = sorted(matches, key=lambda x:x.distance)
	# keep only the top matches
	keep = int(len(matches) * keepPercent)
	matches = matches[:keep]
	# check to see if we should visualize the matched keypoints
	if debug:
		matchedVis = cv2.drawMatches(image, kpsA, template, kpsB,
			matches, None)
		matchedVis = imutils.resize(matchedVis, width=1000)
		cv2.imshow("Matched Keypoints", matchedVis)
		cv2.waitKey(0)

	# allocate memory for the keypoints (x, y)-coordinates from the
	# top matches -- we'll use these coordinates to compute our
	# homography matrix
	ptsA = np.zeros((len(matches), 2), dtype="float")
	ptsB = np.zeros((len(matches), 2), dtype="float")
	# loop over the top matches
	for (i, m) in enumerate(matches):
		# indicate that the two keypoints in the respective images
		# map to each other
		ptsA[i] = kpsA[m.queryIdx].pt
		ptsB[i] = kpsB[m.trainIdx].pt

	# compute the homography matrix between the two sets of matched
	# points
	(H, mask) = cv2.findHomography(ptsA, ptsB, method=cv2.RANSAC)
	# use the homography matrix to align the images
	(h, w) = template1.shape[:2]
	aligned = cv2.warpPerspective(image1, H, (w, h))
	# return the aligned image
	#return aligned
	PIL.Image.fromarray(aligned).save(os.path.join(outputdir, os.path.basename(image)))

	#y = 0
	#x = 0
	#h = 1200
	#w = 1220
	#crop_img = aligned[y:y + h, x:x + w]
	#PIL.Image.fromarray(crop_img).save(os.path.join(outputdir, os.path.basename(image)))



workingDir="D:/Results/align/"

#def maingeomask(workingDir, n):
inputdir = workingDir+"input_img/"
tempdir = workingDir+"refer_temp/"
outputdir = workingDir+"alignment/"
os.makedirs(outputdir, exist_ok=True)
for templates in glob.glob(tempdir + '*.tif'):
	for image in glob.glob(inputdir + '*.tif'):
		align_images(image, templates, outputdir)
