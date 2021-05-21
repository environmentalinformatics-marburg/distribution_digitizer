# distribution_digitizer_students

Installation local the git version of distribution digitizer:

1. Clone or download  the github folder in D: or in C:/Users/~

Task: User the program cmd to clone
D: or C:/Users/~
----------------------------
git clone https://github.com/environmentalinformatics-marburg/distribution_digitizer_students.git
----------------------------
as zip - Extract the files in D: or in C: / Users / ~

2. Prepare the input images
-Download the zip-File mit 20 Book images in distribution_digitizer_students/data/input
-Delete the temp image in this order
-Extract this in distribution_digitizer_students/data/input

3. Start RStudio and open the file installation.R from the distribution_digitizer_students  

User this 3 lines to the start the app
--------------------------------------------------------
setwd ("D:/distribution_digitizer_students/")
library (shiny)
runApp ('app.R')
--------------------------------------------------------
In the function setwd write you path to distribution_digitizer_students

If you did't have shiny library install this with this code
