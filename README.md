# distribution_digitizer_students

Installation local

1. Clone or download  the github folder in D: or in C:/Users/~
Task: User the program cmd to clone
D:\distribution_digitizer_students> D: #or C:/Users/~
git clone https://github.com/environmentalinformatics-marburg/distribution_digitizer_students.git
----------------------------
Task: Download as zip and extract the files in D: or in C: / Users / ~

2. Prepare the input images
Task: Download the zip-Files mit 20 Book images in distribution_digitizer_students/data/input
from  https://environmentalinformatics-marburg.github.io/distribution_digitizer_webpage/data.html
Task: Delete the temp image in distribution_digitizer_students/data/input
Task: Extract the zip-file in distribution_digitizer_students/data/input

3. Start RStudio and open the file installation.R from the distribution_digitizer_students  
User this 3 lines to the start the app
--------------------------------------------------------
setwd ("D:/distribution_digitizer_students/")
library (shiny)
runApp ('app.R')
--------------------------------------------------------
In the function setwd write you path to distribution_digitizer_students

