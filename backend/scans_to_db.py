import global_variables as gv
from datetime import datetime
import time
from mysql.connector.cursor import MySQLCursor
from mysql.connector import pooling




def process_daily_scans():
    gv.logging.info("%s function was called...", process_daily_scans.__name__)

    # DB connection config
    dbconfig = {
        "host": "mysql-db",
        "user": "regular_user",
        "port": "3306",
        "password":"regular_pass",
        "database":"futurium_exhibition_stats"
    }

    try:
        # Connect to the MySQL database
        db_connection_pool = pooling.MySQLConnectionPool(
            pool_name="db_pool_scans_processing",
            pool_size=1,
            pool_reset_session =True,
            **dbconfig
        )

        # get pool name
        pool_name  = db_connection_pool.pool_name
        
    except Exception as e:
        gv.logging.exception("Exception while creating Pool for function %s: %s", process_daily_scans.__name__, e)

    
    

    # counter for tries to insert duplicate code / station combinations per day
    multiple_scan_combi_counter = 0

    
    while True:
        # get current datetime and time
        now = datetime.now()
        currentTime = now.time()
        stop_time = gv.checkEndTimes()
        

        if currentTime > stop_time:  
            try:
                # Retrieve a connection from the pool
                connection = db_connection_pool.get_connection() 
                
                db_Info = connection.get_server_info()

            except ValueError as e:
                gv.logging.error("Error occurred while establishing connection from pool %s: %s", pool_name, e)
            except Exception as e:
                # Log or handle the exception
                gv.logging.exception("Exception while establishing connection from pool %s: %s", pool_name, e)

            try:
                if connection.is_connected():
                    # get connection Pool name
                    gv.logging.info("Succesfully connected to DB using Pool: %s", pool_name)
                    gv.logging.info("Succesfully connected to MySQL Server: %s", db_Info)
                    
                    # Create a cursor object to interact with the database
                    cursor = connection.cursor()               
            except ValueError as e:
                gv.logging.error("Error occurred while creating cursor from connection to pool %s: %s", pool_name, e)
            except Exception as e:
                # Log or handle the exception
                gv.logging.exception("Exception while creating cursor from connection to pool %s: %s", pool_name, e)


            gv.logging.info("Parsing daily scans to DB...")

            # Open the token log file for reading
            file = open(gv.daily_scans_file, "r+") # uncomment this for daily parsing (normal betrieb)
            #file = open(gv.scans_archive_file, "r") # only use this when passing data en masse usually when restoring or initiating backups
            lines = file.readlines()

            

            for line in lines:
                try:
                    # Split the line into its component
                    parts = line.strip().split("__")
                    scan_date = gv.format_date_for_db(parts[0].split("_")[0])
                    scan_time = parts[0].split("_")[1]
                    station_id = parts[1].split("/")[1]
                    band_code = parts[1].split('"')[1].strip()
                except ValueError as e:
                    gv.logging.error("ERROR at Scan string processing!")
                except Exception as e:
                    gv.logging.exception("Exception at Scan string processing!")
                try:
                    if gv.is_valid_armband_code(band_code):
                        #Construct the SQL query to insert the values into the "scans" table
                        query = "INSERT INTO scans (scan_date, scan_time, scan_station_id, scan_band_code) VALUES (%s, %s, %s, %s)"
                        values = (scan_date, scan_time, station_id, band_code)
                        print(query)
                        #Execute the SQL query
                        cursor.execute(query, values)
                    else:
                        raise Exception("Invalid Armband code format!")
                except Exception as e:
                    multiple_scan_combi_counter += 1
                    #gv.logging.exception("INSERT : ")
                
                try: 
                    #Commit the changes to the database
                    connection.commit()
                except:
                    #Log or handle the exception
                    gv.logging.exception("Exception while commiting to DB: ")

            # Move the file pointer to the start of the file
            file.seek(0)
            # empty daily scans file
            file.truncate(0)
            #close file
            file.close()  
            

            
            # Close the cursor and database connection
            cursor.close()
            # close connection
            connection.close()

            gv.logging.info("Parsing Token Scans Completed Succesfully!")
            gv.logging.info("After today's parsing of scans in DB number of excesive/multiple scans is: " + str(multiple_scan_combi_counter))
            gv.logging.info("Waiting 12 hours until checking time for parsing token scans again...")
            time.sleep(43200)
        else:
            #gv.logging.info("Check if time to parse (once every Hour)")
            time.sleep(60)
            continue
        
