import global_variables as gv
from datetime import datetime
import time
import global_variables as gv
from global_variables import db_connection_pool
from mysql.connector.cursor import MySQLCursor
import mysql.connector



def process_daily_scans():
    
    # get current datetime and time
    now = datetime.now()
    currentTime = now.time()
    stop_time = gv.checkEndTimes()

    gv.logging.info("Parsing func started...")

    # counter for tries to insert duplicate code / station combinations per day
    multiple_scan_combi_counter = 0

    
    while True:
        # get current datetime and time
        now = datetime.now()
        currentTime = now.time()
        stop_time = gv.checkEndTimes()
        
        # empty lines
        lines = []

        if currentTime > stop_time:  
            try:

                # Retrieve a connection from the pool
                connection = db_connection_pool.get_connection()

                # Create a cursor object to interact with the database
                cursor = MySQLCursor(connection)
                
            except Exception as e:
                # Log or handle the exception
                gv.logging.exception("Exception while establishing database connection: ")


            gv.logging.info("Parsing daily scans to DB...")

            # Open the token log file for reading
            with open(gv.daily_scans_file, "w+") as file:
                lines = file.readline()

                #if any(line.strip() for line in lines):
                    # Process each line in the file
                for line in file:
                    try:
                        # Split the line into its components
                        parts = line.strip().split("__")
                        scan_date, scan_time = parts[0].split("_")
                        station_id = parts[1].split("/")[1]
                        band_code = parts[1].split('"')[1].strip()
                        #print(scan_date, scan_time)

                        #Construct the SQL query to insert the values into the "scans" table
                        query = "INSERT INTO scans (scan_date, scan_time, scan_station_id, scan_band_code) VALUES (%s, %s, %s, %s)"
                        values = (scan_date, scan_time, station_id, band_code)

                        #Execute the SQL query
                        cursor.execute(query, values)
                    except Exception as e:
                        multiple_scan_combi_counter += 1
                        gv.logging.exception("Exception while executing INSERT Query: ")
                

                # Move the file pointer to the end of the file
                file.seek(0, 2)
                # empty daily scans file
                file.truncate()
                        
            try: 
                # Commit the changes to the database
                cursor.commit()
            except:
                # Log or handle the exception
                gv.logging.exception("Exception while commiting: ")

            finally: 
                # Close the cursor and database connection
                cursor.close()
                connection.close()

                gv.logging.info("Parsing Completed Succesfully!")
                gv.logging.info("After daily parsing of scans in DB number of excesive/multiple scans is: " + str(multiple_scan_combi_counter))
                gv.logging.info("Waiting 12 hours until checking time for parsing again...")
                time.sleep(43200)
            
        
        else:
            gv.logging.info("Check if time to parse (once every Hour)")
            time.sleep(10)
            continue
        
            
# Call the function to process the token logs
#process_daily_scans()     
