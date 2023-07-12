import global_variables as gv
from datetime import datetime
import time
from mysql.connector.cursor import MySQLCursor
from mysql.connector import pooling

import pandas as pd
import plotly.express as px
import plotly.graph_objs as go
import plotly.io as pio
from datetime import datetime, date
import numpy as np
import global_variables
import os
import base64


def process_scan_times():

    gv.logging.info("%s function was called...", process_scan_times.__name__)

    # 1. Connect to DB

    # create a connection pool
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
            pool_name="db_pool_times_processing",
            pool_size=1,
            pool_reset_session =True,
            **dbconfig
        )

        # get pool name and server info
        pool_name  = db_connection_pool.pool_name
        
    except Exception as e:
        gv.logging.exception("Exception while creating Pool for function %s : %s",process_scan_times.__name__, e)

    # establish a connection
    try:
        # Retrieve a connection from the pool
        connection = db_connection_pool.get_connection() 
        db_Info = connection.get_server_info()
    except ValueError as e:
        gv.logging.error("Error occurred while establishing connection from pool %s: %s", pool_name, e)
    except Exception as e:
        # Log or handle the exception
        gv.logging.exception("Exception while establishing connection from pool %s: %s", pool_name, e)
    
    # create cursor to interact with DB
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


    # 2. Read in the token_stations table as dataframe
    try:
        #Construct the SQL query to get the token stations table from DB
        query = "SELECT tk_station_id, theme_area, tk_type FROM `token_stations`"

        #Execute the SQL query
        cursor.execute(query)

        ## Retrieve the returned data
        query_result = cursor.fetchall()

    except Exception as e:
        gv.logging.exception("Exception during query excecution '%s' in %s : \n %s ", 
                             query, process_scan_times.__name__, e)
    
    # token_stations table as dataframe
    token_stations_df = pd.DataFrame(query_result) 
    #print(token_stations_df)

    # 3. Calculate times for regions for today

    # create list to contain the time sums per region read by the daily token scan log
    day_sums = {"technology": 0.0,
               "nature": 0.0,
               "human": 0.0,
               "interactive": 0.0}  

    # open token_daily_log for reading as rfile
    with open(gv.daily_scans_file, "r") as rfile:  # open token_daily_log for reading as rfile
        # read the data on rfile line by line
        daily_scans = rfile.readlines()
        # list to put all individual armband codes from daily_scans_file
        today_codes = list()  

        # add all distinct armband codes from daily_scans_file in todays_codes list
        for line in daily_scans:
            scan_band_code = line.split('"')[1].strip()  # get bracelet code
            # only add distinct armband codes
            if scan_band_code not in today_codes:
                today_codes.append(scan_band_code)

    
        # calculate times
        for i in today_codes:
            print("current code: %s ", i)
            # list of touples to tempsave the region and time, 
            # every time the currently iterated code appears in the log file
            t_occurence_perCode = list()  

        # dict to temp save the sums hours spend in regions per currently iterated  code
            t_SumsPerCode = {
                    "technology": 0.0,
                    "nature": 0.0,
                    "human": 0.0,
                    "interactive": 0.0
                }

            # iterate through daily_scans again, line by line
            for line in daily_scans:
                # get time from line  
                scan_time = datetime.strptime(line.split("_")[1].strip(), "%H:%M:%S").time()  
                # get token_station_id from line
                tk_station_id = line.split("/")[1].strip()
                # get armband_code from line
                armband_code = line.split('"')[1].strip()  # get bracelet code

                # i = one of todays_codes and armband_code is the arband code of current line
                if i == armband_code:  
                    # look in token_stations_df
                    # if the tk_statioin_id from the the df matches the id in current line

                    for id in token_stations_df[0]:
                        if tk_station_id == id:
                            print(tk_station_id + " : " + region)
    #               for e in id_region_map:  
    #                     if e[0] in tokenstationId: 
    #                         # print(e[0]+ " : " + tokenstationId)
    #                         region = e[1]  # then that its mapped region
    #                         tempToupple = (
    #                         region, time)  # the touple of region and time to add in temp list t_occurence_perCode
    #                         t_occurence_perCode.append(tempToupple)  # append it to the list

    #                 ######graph map
    #                 if today_codes.index(i) < 5:
    #                     for id in stations_ids:
    #                         if "Vote" in id:
    #                             if tokenstationId == id or tokenstationId[:-1] + "A/B/C" == id:
    #                                 if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
    #                                         not in x[today_codes.index(i)] and stations_y[
    #                                     coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
    #                                         not in y[today_codes.index(i)]:
    #                                     x[today_codes.index(i)].append(
    #                                         stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
    #                                     y[today_codes.index(i)].append(
    #                                         stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
    #                                     point_times[today_codes.index(i)].append(str(time))

    #                         elif tokenstationId == id:

    #                             if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
    #                                     not in x[today_codes.index(i)] and stations_y[
    #                                 coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
    #                                     not in y[today_codes.index(i)]:
    #                                 x[today_codes.index(i)].append(
    #                                     stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
    #                                 y[today_codes.index(i)].append(
    #                                     stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
    #                                 point_times[today_codes.index(i)].append(str(time))

    #         firstindex = 0
    #         # continue reading data for times
    #         for t in t_occurence_perCode:  # iterate through the touple list for code currently being processed
    #             reg1 = t[0]  # get the region of each touple
    #             currCodeTime = t[1]  # get the time for each toupple

    #             secondIndex = 0
    #             for r in t_occurence_perCode[
    #                      firstindex + 1:]:  # iterate through the touple list once more starting from next index

    #                 # if reg1 == reg2 or reg1 !=:#if the region from loop matches the one from this loop
    #                 delta = datetime.combine(date.today(), r[1]) - datetime.combine(date.today(),
    #                                                                                 currCodeTime)  # calculate time diferrence
    #                 # currCodeTime = r[1]

    #                 for key in t_SumsPerCode.keys():
    #                     if key == reg1:
    #                         t_SumsPerCode[key] += delta.total_seconds() / 3600  # seconds per hour

    #                 secondIndex += 1
    #                 break
    #             firstindex += 1

    #         ###########graph map
    #         # add the sum times of code currently iterated to the dict containing the sum times for today
    #         day_sums["Technik"] += t_SumsPerCode["Technik"]
    #         day_sums["Natur"] += t_SumsPerCode["Natur"]
    #         day_sums["Mensch"] += t_SumsPerCode["Mensch"]
    #         day_sums["Genetic"] += t_SumsPerCode["Genetic"]

    # region_time_df.iat[0, 1] = (region_time_df.iat[0, 1]) + (day_sums["Technik"] / float(len(today_codes)))
    # region_time_df.iat[0, 2] = (region_time_df.iat[0, 2]) + (day_sums["Natur"] / float(len(today_codes)))
    # region_time_df.iat[0, 3] = (region_time_df.iat[0, 3]) + (day_sums["Mensch"] / float(len(today_codes)))
    # region_time_df.iat[0, 4] = (region_time_df.iat[0, 4]) + (day_sums["Genetic"] / float(len(today_codes)))
    # region_time_df.to_csv(region_time_database, index=False)  # contains average time spend per region per armband

    # ####graphs
    # regionTimesAvgFig = px.pie(region_time_df, names=["Technik", "Natur", "Mensch", "Genetic"],
    #                            values=region_time_df.iloc[0, 1:], title="Average Time per Region per Armband in Hours")
    # dateTotalArmbandsFig = px.bar(totalArmbands_df, x="Date", y="Armbands",
    #                                title="Total Armbands per Day\n Total Armbands since " + sinceDate + " = " + totalArmbandsAlltime)

    # pio.write_html(regionTimesAvgFig, file=str(global_variables.region_average_times), auto_open=False)
    # pio.write_html(dateTotalArmbandsFig, file=str(global_variables.exhibition_visitors), auto_open=False)

    # #######################################################################

    # with open(os.getcwd() + "/tokenmap.png", "rb") as image_file:
    #     encoded_string = base64.b64encode(image_file.read()).decode()
    # # Add the prefix that plotly will want when using the string as source
    # encoded_image = "data:image/png;base64," + encoded_string

    # fig = go.Figure()
    # # Add image
    # img_width = 2380
    # img_height = 1992
    # # scale_factor = 0.5
    # fig.add_layout_image(
    #     x=0,
    #     sizex=img_width,
    #     y=0,
    #     sizey=img_height,
    #     xref="x",
    #     yref="y",
    #     opacity=1.0,
    #     layer="below",
    #     source=encoded_image
    # )
    # fig.update_xaxes(showgrid=False, range=(0, img_width))
    # fig.update_yaxes(showgrid=False, scaleanchor='x', range=(img_height, 0))

    # colors = ["yellow", "blue", "green", "cyan", "purple"]
    # symbols = ["circle-dot", "square-dot", "diamond-dot", "x-dot", "star-dot"]
    # iteration_counter = 0
    # for i in x:
    #     color = colors[iteration_counter]
    #     # add start marker
    #     fig.add_trace(go.Scatter(x=np.array(i[0]), y=np.array(y[iteration_counter][0]), mode='markers',
    #                              name='Start ' + point_times[iteration_counter][0],
    #                              marker={'size': 12, 'symbol': symbols[iteration_counter],
    #                                      'color': colors[iteration_counter]}))
    #     iteration_counter2 = 0
    #     for e in i:
    #         if i.index(e) < len(i) - 1:
    #             x_zero = i[iteration_counter2]
    #             y_zero = y[iteration_counter][iteration_counter2]
    #             x_one = i[iteration_counter2 + 1]
    #             y_one = y[iteration_counter][iteration_counter2 + 1]

    #             # add point marker
    #             fig.add_trace(go.Scatter(x=np.array(x_one), y=np.array(y_one), mode='markers',
    #                                      name=point_times[iteration_counter][iteration_counter2 + 1],
    #                                      marker={'size': 8, 'symbol': symbols[iteration_counter],
    #                                              'color': colors[iteration_counter]}))

    #             # draw line
    #             fig.add_shape(type='line', xref='x', yref='y',
    #                           x0=x_zero, x1=x_one, y0=y_zero, y1=y_one, line_color=color)
    #             iteration_counter2 += 1
    #     iteration_counter += 1

    # # Set dragmode and newshape properties; add modebar buttons
    # fig.update_layout(
    #     dragmode='drawrect',
    #     newshape=dict(line_color='cyan'),
    #     title_text='Exhibition Paths'
    # )

    # pio.write_html(fig, config={'modeBarButtonsToAdd': ['drawline',
    #                                                     'drawopenpath',
    #                                                     'drawclosedpath',
    #                                                     'drawcircle',
    #                                                     'drawrect',
    #                                                     'eraseshape'
    #                                                     ]},
    #                file=str(global_variables.exhibitions_paths), auto_open=False)
    # print("Reached end of graphing times and paths...")


#graph_time_path_visits(global_variables.timeperRegion_Database, global_variables.tokenStation_coordinates,
                       #global_variables.log_archive, global_variables.total_armbaender)
