# 🌍 Distribution Digitizer

The **Distribution Digitizer** is a semi-automated software framework designed to extract, reconstruct, and spatially integrate species distribution data from scanned historical maps and associated book pages.

The system combines **computer vision, Optical Character Recognition (OCR), and geospatial processing** within a hybrid **Python–R architecture**, enabling the transformation of analogue biodiversity data into structured and georeferenced datasets.

---

## 🧠 Concept and Motivation

Historical species distribution data is often available only in analogue form, embedded in printed maps and textual descriptions. Manual digitization of such data is time-consuming and error-prone.

The Distribution Digitizer addresses this challenge by providing a reproducible workflow that:

- detects maps within scanned book pages  
- extracts species information from map legends  
- links species to visual symbols (colors)  
- enriches species with contextual titles from book text  
- transforms detected points into spatial data  
- integrates all information into a unified dataset  

---

## ⚙️ System Architecture

The workflow is implemented using:

- **Python** → image processing, OCR, template matching  
- **R** → data integration, CSV processing, visualization  
- **GDAL / PROJ** → geospatial transformations  
- **Tesseract OCR** → text extraction  

---

## 🔄 Workflow Overview

The complete pipeline consists of seven sequential stages:

---

### **1. GUI-Based Configuration**

The process starts with a graphical user interface where the user defines:

- Book metadata (title, author)  
- Number of map types  
- Legend positions (top / bottom)  
- Legend keywords (e.g., *"distribution of"*)  
- Title extraction parameters (year, position)  
- Input and output directories  

---

### **2. Template Preparation (User-Guided)**

#### 2.1 Map Cropping
- Selection of representative map regions  
- Used for map detection and alignment  

#### 2.2 Legend Cropping
- Extraction of symbol templates (e.g., colored points)  
- Used for symbol recognition  

⚠️ Template quality strongly influences detection accuracy.

---

### **3. Scanned Book Pages Processing**

#### 3.1 Template Matching
- Detection of maps within scanned pages  
- Output stored in:
  `coordinates.csv`

#### 3.2 Map Alignment
- Vertical (Y-axis) alignment of detected maps  

---

### **4. Scanned Maps Processing**

#### 4.1 Point Matching
- Detection of symbol occurrences via template matching  

#### 4.2 Point Filtering
- Removal of false positives  
- Refinement of detections  

#### 4.3 Masking and OCR Analysis
- Removal of irrelevant map regions  
- OCR-based extraction of legend text  
- Identification of species names  

---

### **5. Species Extraction from Book Pages**

This stage enriches species information using textual context:

- OCR-based extraction from book pages  
- Keyword-based detection (e.g., "Range")  
- Filtering of irrelevant lines (e.g., "distribution")  
- Detection of structural patterns (e.g., publication years)  
- Multi-page fallback (previous / next page)  

Result:
- Structured species–title associations  

---

### **6. Coordinate Integration**

#### 6.1 Georeferencing
- Transformation into geographic coordinate systems  

#### 6.2 Rectifying
- Correction of spatial distortions  

#### 6.3 Polygonization
- Conversion of points into spatial polygons  
- Output:
  `polygonize.csv`

---

### **7. Spatial Data Processing and Visualization**

- Matching and merging of datasets  
- Integration of:
  - species  
  - location  
  - title  

Visualization includes:

- OpenStreetMap  
- Species distribution points  
- Map titles and metadata  

---

## 🔗 Data Flow

| Stage | Output |
|------|--------|
| Map detection | coordinates.csv |
| Species extraction | enriched coordinates.csv |
| Polygonization | polygonize.csv |
| Final output | spatial dataset |

---

## 🧪 Methodological Highlights

- OCR-based text extraction with error-tolerant matching (Levenshtein similarity)  
- Template matching using normalized cross-correlation (OpenCV)  
- Combined local and global symbol detection  
- Rule-based text filtering and pattern recognition  
- Integration of textual and spatial data  

---

## 🚧 Current Limitations

- Limited number of symbol classes (~6 colors)  
- Static legend keywords (GUI-defined)  
- Dependency on template quality  
- OCR errors may affect accuracy  

---

## 🚀 Recent Improvements (2026)

Significant effort has been invested in improving performance and scalability:

- Reduction of redundant computations  
- Optimization of template matching workflows  
- Improved memory handling  
- Preparation for **parallel processing of large datasets**  

Future versions will introduce:

- Multi-core parallelization  
- GPU acceleration (optional)  
- Dynamic keyword detection  

---

## 📦 Installation

➡️ See full installation guide:  
**[INSTALL.md](INSTALL.md)**

---

## ▶️ Running the Application

```r
setwd("D:/distribution_digitizer")
options(shiny.port = 8888, shiny.host = "127.0.0.1")
shiny::runApp("app")
