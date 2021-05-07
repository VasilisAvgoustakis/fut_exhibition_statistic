import pandas as pd
import plotly.express as px
import plotly.graph_objs as go
import plotly.io as pio
from datetime import datetime, date
import numpy as np
import global_variables
import os
import base64


def graph_time_path_visits(region_time_database, coordinates_file, daily_scan_log, total_armbaender_database):
    # make new csv file and Dataframe for counting time per region
    data = pd.read_csv(region_time_database)
    region_time_df = pd.DataFrame(data)
    day_sums = {"Technik": 0.0,
               "Natur": 0.0,
               "Mensch": 0.0,
               "Genetic": 0.0}  # list contains the time sums for each region read by the daily token scan log

    # read token database as dataframe
    token_database = pd.read_csv(global_variables.tokenDatabase)
    token_df = pd.DataFrame(token_database)

    # read questions Database as Dataframe
    questions_database = pd.read_csv(global_variables.questionsDatabase)
    questions_df = pd.DataFrame(questions_database)

    # read coordinates
    coordinates = pd.read_csv(coordinates_file)
    coordinates_df = pd.DataFrame(coordinates)
    stations_ids = coordinates_df["Token IDs"]
    stations_x = coordinates_df["x"]
    stations_y = coordinates_df["y"]

    # list of tupples for mapping token ids to regions
    id_region_map = list()

    # Map tokenIDs to Regions and add as tupple to the list above
    for i in token_df["TokenIDs"]:
        token_id = i
        bereich = token_df["Bereich"][
            list(token_df["TokenIDs"]).index(i)]  # get the region for every token id from token tokendatabase
        id_region_tuple = (token_id, bereich)  # tupple to be added to list with every iterations
        id_region_map.append(id_region_tuple)

    # do the same as above for the Base IDs in the questions Database
    for i in questions_df["Base ID"]:
        question_id = i
        question_bereich = questions_df["Bereich"][list(questions_df["Base ID"]).index(i)]
        id_region_tuple = (question_id, question_bereich)
        id_region_map.append(id_region_tuple)

    
    with open(daily_scan_log, "r") as rfile:  # open token_daily_log for reading as rfile
        # read the data on rfile line by line
        log_data = rfile.readlines()
        today_codes = list()  # list containing all individual armband codes from token daily log

        # add all armband codes from todays log in todayscodes list
        for line in log_data:
            code = line.split('"')[1].strip()  # get bracelet code
            if code not in today_codes:
                today_codes.append(code)

        # add daily armbands count to total armbands database with todays date as new row
        new_row = {'Date': date.today(), 'Armbands': len(today_codes)}
        totalArmbandsData = pd.read_csv(total_armbaender_database)
        totalArmbands_df = pd.DataFrame(totalArmbandsData)
        totalArmbands_df = totalArmbands_df.append(new_row, ignore_index=True)
        totalArmbandsAlltime = str(int(totalArmbands_df.sum(axis=0)))
        sinceDate = str(totalArmbands_df.iat[0, 0])
        # print(float(totalArmbandsAlltime[0]))
        totalArmbands_df.to_csv(total_armbaender_database, index=False)

        # gather data to graph paths

        x = [[] for i in range(5)]  # add as many indexes to the lists as armbands to make paths of
        y = [[] for i in range(5)]
        point_times = [[] for i in range(5)]

        for i in today_codes:
            t_occurence_perCode = list()  # list fo touples to temp save the region and time, every time the currently iterated code appears in the log file

            # dict to temp save the sums hours spend in regions per currently iterated  code
            t_SumsPerCode = {
                "Technik": 0.0,
                "Natur": 0.0,
                "Mensch": 0.0,
                "Genetic": 0.0
            }

            for line in log_data:  # iterate through log again, line by line
                time = datetime.strptime(line.split("_")[1].strip(), "%H:%M:%S").time()  # get time in line
                tokenstationId = line.split("/")[1].strip()  # get token id in line
                code = line.split('"')[1].strip()  # get bracelet code
                if i == code:  # i = one of todays armband codes and code is the arband code of current line
                    for e in id_region_map:  # iterate through region map list of touples
                        if e[0] in tokenstationId:  # if the tokendi in the toupple matches the id in current line
                            # print(e[0]+ " : " + tokenstationId)
                            region = e[1]  # then that its mapped region
                            tempToupple = (
                            region, time)  # the touple of region and time to add in temp list t_occurence_perCode
                            t_occurence_perCode.append(tempToupple)  # append it to the list

                    ######graph map
                    if today_codes.index(i) < 5:
                        for id in stations_ids:
                            if "Vote" in id:
                                if tokenstationId == id or tokenstationId[:-1] + "A/B/C" == id:
                                    if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                            not in x[today_codes.index(i)] and stations_y[
                                        coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                            not in y[today_codes.index(i)]:
                                        x[today_codes.index(i)].append(
                                            stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                        y[today_codes.index(i)].append(
                                            stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                        point_times[today_codes.index(i)].append(str(time))

                            elif tokenstationId == id:

                                if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                        not in x[today_codes.index(i)] and stations_y[
                                    coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                        not in y[today_codes.index(i)]:
                                    x[today_codes.index(i)].append(
                                        stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                    y[today_codes.index(i)].append(
                                        stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                    point_times[today_codes.index(i)].append(str(time))

            firstindex = 0
            # continue reading data for times
            for t in t_occurence_perCode:  # iterate through the touple list for code currently being processed
                reg1 = t[0]  # get the region of each touple
                currCodeTime = t[1]  # get the time for each toupple

                secondIndex = 0
                for r in t_occurence_perCode[
                         firstindex + 1:]:  # iterate through the touple list once more starting from next index

                    # if reg1 == reg2 or reg1 !=:#if the region from loop matches the one from this loop
                    delta = datetime.combine(date.today(), r[1]) - datetime.combine(date.today(),
                                                                                    currCodeTime)  # calculate time diferrence
                    # currCodeTime = r[1]

                    for key in t_SumsPerCode.keys():
                        if key == reg1:
                            t_SumsPerCode[key] += delta.total_seconds() / 3600  # seconds per hour

                    secondIndex += 1
                    break
                firstindex += 1

            ###########graph map
            # add the sum times of code currently iterated to the dict containing the sum times for today
            day_sums["Technik"] += t_SumsPerCode["Technik"]
            day_sums["Natur"] += t_SumsPerCode["Natur"]
            day_sums["Mensch"] += t_SumsPerCode["Mensch"]
            day_sums["Genetic"] += t_SumsPerCode["Genetic"]

    region_time_df.iat[0, 1] = (region_time_df.iat[0, 1]) + (day_sums["Technik"] / float(len(today_codes)))
    region_time_df.iat[0, 2] = (region_time_df.iat[0, 2]) + (day_sums["Natur"] / float(len(today_codes)))
    region_time_df.iat[0, 3] = (region_time_df.iat[0, 3]) + (day_sums["Mensch"] / float(len(today_codes)))
    region_time_df.iat[0, 4] = (region_time_df.iat[0, 4]) + (day_sums["Genetic"] / float(len(today_codes)))
    region_time_df.to_csv(region_time_database, index=False)  # contains average time spend per region per armband

    ####graphs
    regionTimesAvgFig = px.pie(region_time_df, names=["Technik", "Natur", "Mensch", "Genetic"],
                               values=region_time_df.iloc[0, 1:], title="Average Time per Region per Armband in Hours")
    dateTotalArmbandsFig = px.bar(totalArmbands_df, x="Date", y="Armbands",
                                   title="Total Armbands per Day\n Total Armbands since " + sinceDate + " = " + totalArmbandsAlltime)

    pio.write_html(regionTimesAvgFig, file=str(global_variables.region_average_times), auto_open=False)
    pio.write_html(dateTotalArmbandsFig, file=str(global_variables.exhibition_visitors), auto_open=False)

    #######################################################################

    with open(os.getcwd() + "/tokenmap.png", "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode()
    # Add the prefix that plotly will want when using the string as source
    encoded_image = "data:image/png;base64," + encoded_string

    fig = go.Figure()
    # Add image
    img_width = 2380
    img_height = 1992
    # scale_factor = 0.5
    fig.add_layout_image(
        x=0,
        sizex=img_width,
        y=0,
        sizey=img_height,
        xref="x",
        yref="y",
        opacity=1.0,
        layer="below",
        source=encoded_image
    )
    fig.update_xaxes(showgrid=False, range=(0, img_width))
    fig.update_yaxes(showgrid=False, scaleanchor='x', range=(img_height, 0))

    colors = ["yellow", "blue", "green", "cyan", "purple"]
    symbols = ["circle-dot", "square-dot", "diamond-dot", "x-dot", "star-dot"]
    iteration_counter = 0
    for i in x:
        color = colors[iteration_counter]
        # add start marker
        print("x = ", x)
        print("y = ", y)
        fig.add_trace(go.Scatter(x=np.array(i[0]), y=np.array(y[iteration_counter][0]),
                                 mode='markers',
                                 name='Start ' + point_times[iteration_counter][0],
                                 marker={'size': 12, 'symbol': symbols[iteration_counter],
                                         'color': colors[iteration_counter]}))
        iteration_counter2 = 0
        for e in i:
            if i.index(e) < len(i) - 1:
                x_zero = i[iteration_counter2]
                y_zero = y[iteration_counter][iteration_counter2]
                x_one = i[iteration_counter2 + 1]
                y_one = y[iteration_counter][iteration_counter2 + 1]

                # add point marker
                fig.add_trace(go.Scatter(x=np.array(x_one), y=np.array(y_one), mode='markers',
                                         name=point_times[iteration_counter][iteration_counter2 + 1],
                                         marker={'size': 8, 'symbol': symbols[iteration_counter],
                                                 'color': colors[iteration_counter]}))

                # draw line
                fig.add_shape(type='line', xref='x', yref='y',
                              x0=x_zero, x1=x_one, y0=y_zero, y1=y_one, line_color=color)
                iteration_counter2 += 1
        iteration_counter += 1

    # Set dragmode and newshape properties; add modebar buttons
    fig.update_layout(
        dragmode='drawrect',
        newshape=dict(line_color='cyan'),
        title_text='Exhibition Paths'
    )

    pio.write_html(fig, config={'modeBarButtonsToAdd': ['drawline',
                                                        'drawopenpath',
                                                        'drawclosedpath',
                                                        'drawcircle',
                                                        'drawrect',
                                                        'eraseshape'
                                                        ]},
                   file=str(global_variables.exhibitions_paths), auto_open=False)
    print("Reached end of graphing times and paths...")


#graph_time_path_visits(global_variables.timeperRegion_Database, global_variables.tokenStation_coordinates,
                       #global_variables.log_archive, global_variables.total_armbaender)
