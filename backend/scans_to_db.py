import global_variables as gv
from global_variables import db
from datetime import datetime
import time
import global_variables as gv



def process_daily_scans():
    
    # get current datetime and time
    now = datetime.now()
    currentTime = now.time()
    stop_time = gv.checkEndTimes()

    gv.logging.info("Parsing func started...")

    # counter for tries to insert duplicate code / station combinations per day
    multiple_scan_combi_counter = 0
    
    while True:
        if currentTime > stop_time:
            # Create a cursor object to interact with the database
            cursor = db.cursor()

            gv.logging.info("Parsing daily scans to DB...")

            # Open the token log file for reading
            with open(gv.daily_scans_file, "r+") as file:
                # Process each line in the file
                for line in file:
                    
                    # Split the line into its components
                    parts = line.strip().split("__")
                    scan_date, scan_time = parts[0].split("_")
                    station_id = parts[1].split("/")[1]
                    band_code = parts[1].split('"')[1].strip()
                    #print(date, time, station_id, band_code)

                    #Construct the SQL query to insert the values into the "scans" table
                    query = "INSERT INTO scans (scan_date, scan_time, scan_station_id, scan_band_code) VALUES (%s, %s, %s, %s)"
                    values = (scan_date, scan_time, station_id, band_code)

                    #Execute the SQL query
                    try:
                        cursor.execute(query, values)
                    except:
                        multiple_scan_combi_counter += 1

                # empty daily scans file
                file.truncate()
                        

            # Commit the changes to the database
            db.commit()

            # Close the cursor and database connection
            cursor.close()
            db.close()

            

            gv.logging.info("Parsing Completed Succesfully!")
            gv.logging.info("After daily parsing of scans in DB number of excesive/multiple scans is: " + str(multiple_scan_combi_counter))
            gv.logging.info("Waiting 12 hours until checking time for parsing again...")
            #time.sleep(43200)
            time.sleep(60)
        
        else:
            time.sleep(5)
            continue
        
            
# Call the function to process the token logs
# process_daily_scans()     
