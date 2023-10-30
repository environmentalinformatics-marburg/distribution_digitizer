"""
Script for initializing and appending csv files for coordinate extraction.
"""

# define functions for initializing csv file
def initialize_csv_file(output_dir):
    csv_file_path = os.path.join(output_dir, "coordinates.csv")
    if not os.path.exists(csv_file_path):
        with open(csv_file_path, mode='w', newline='') as csv_file:
            csv_writer = csv.writer(csv_file)
            csv_writer.writerow(['File', 'Detection method', 'X', 'Y'])
    return csv_file_path

# define function for appending existing csv file
def append_to_csv_file(csv_file_path, coordinates, file_name, method):
    with open(csv_file_path, mode='a', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)
        csv_writer.writerows([(file_name, method, x, y) for x, y in coordinates])
