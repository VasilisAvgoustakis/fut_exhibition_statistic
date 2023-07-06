import global_variables as gv
from datetime import datetime
import time
from mysql.connector import pooling
from mysql.connector import Error

def process_daily_asset_calls():

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
            pool_name="db_pool_assets",
            pool_size=1,
            pool_reset_session =True,
            **dbconfig
        )
    except Exception as e:
        gv.logging.exception("Exception while creating Pool: %s", e)


    gv.logging.info("Parsing daily Asset calls function was called...")

    while True:

        # get current datetime and time
        now = datetime.now()
        currentTime = now.time()
        stop_time = gv.checkEndTimes()

        if currentTime > stop_time:
            try:
                # Retrieve a connection from the pool
                connection = db_connection_pool.get_connection() 
            except ValueError as e:
                gv.logging.error("Error occurred while establishing database connection for Asset Parsing: %s", e)
            except Exception as e:
                # Log or handle the exception
                gv.logging.exception("Exception while establishing database connection for Asset Parsing: %s", e)


            try:
                if connection.is_connected():
                    # get connection Pool name
                    pool_name  = db_connection_pool.pool_name
                    gv.logging.info("Succesfully connected to DB using Pool: %s", pool_name)
                    db_Info = connection.get_server_info()
                    gv.logging.info("Succesfully to MySQL Server: %s", db_Info)
                    
                    # Create a cursor object to interact with the database
                    cursor = connection.cursor()               
            except ValueError as e:
                gv.logging.error("Error occurred while creating cursor: %s", e)
            except Exception as e:
                # Log or handle the exception
                gv.logging.exception("Exception while creating cursor: %s", e)


            gv.logging.info("Parsing daily Asset calls to DB...")


            # Open the asset log file for reading
            file = open(gv.daily_asset_log, "r", encoding="utf-8")
            lines = file.readlines()

            for line in lines:
                # get asset name
                asset_name = line.split("GET")[1].split("/")[2][:-5]

                if "/assets" in line:
                    # process only if it is not an "Idle" Asset
                    if "Idle" not in asset_name and ".mp4" in asset_name:
                        ip_addr = line.split("- -")[0] # get IP
                        date_time_str = line.split("- -")[1].split("]")[0][2:] # extract datetime str
                        date_time = datetime.strptime(date_time_str, "%d/%b/%Y:%H:%M:%S %z") # create datetime object
                        
                        date_db_format = str(date_time.date()) # format date as str for DB
                        call_time = date_time.time() # time object
                        # calling an asset more than once within the same minute per day is counted as 1 call
                        # thus we save the time in the DB setting the seconds to '00' which in combination with a unique index 
                        # for the table 'asset_calls' for the columns (call_date, call_time, device_ip) makes sure we only store 
                        # 1 call per minute per device per day. This makes the data more representative by supposing that 
                        # if an asset is called more than once withing the same minute, it is done by the same visitor

                        time_db_format = str(call_time.replace(second=0)) # format time as str for DB


                        # get the device name and area an media id
                        if "device=" in line:
                            device_info =  line.split("device=")[1].split("&")
                            device_name = device_info[0]
                            if '"' in device_name:
                                device_name = device_name.split('"')[0]

                            if len(device_info) >= 2:
                                if "configPath" in device_info[1]:
                            
                                    area_name = device_info[1].split("=")[1].split("2F")[0][:-1]
                                    media_id = device_info[1].split("=")[1].split("2F")[1].split('"')[0]
                                else: area_name = "unknown"
                        else:
                            device_name = "no_device"
                            area_name = "no_area"
                            
                        
                        #print(date_db_format, time, time_db_format, ip_addr, device_name, area_name, media_id, asset_name[0:20])

                        # only store calls that are within opening times
                        if call_time >= gv.sub_start_time and call_time <= gv.checkEndTimes():
                            try:
                                #Construct the SQL query to insert the values into the "scans" table
                                query = "INSERT INTO asset_calls (call_date, call_time, device_ip, device_name, area_name, media_id, asset_name) VALUES (%s, %s, %s, %s, %s, %s, %s)"
                                values = (date_db_format, time_db_format, ip_addr, device_name, area_name, media_id, asset_name[0:20])

                                #Execute the SQL query
                                cursor.execute(query, values)
                            except Exception as e:
                                pass
                            
                            try: 
                                #Commit the changes to the database
                                connection.commit()
                            except:
                                #Log or handle the exception
                                gv.logging.exception("Exception while commiting assets to DB: ")

            #close file
            file.close()  
            # Close the cursor and database connection
            cursor.close()
            # close connection
            connection.close()

            gv.logging.info("Parsing Asset Calls Completed Succesfully!")
            gv.logging.info("Waiting 24 hours until checking time for parsing asset calls again...")
            time.sleep(86400)

        else:
            #gv.logging.info("Check if time to parse (once every Hour)")
            time.sleep(60)
            continue            
