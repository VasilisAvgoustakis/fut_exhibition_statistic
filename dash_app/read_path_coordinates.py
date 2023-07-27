import urllib.request
import pandas as pd
from datetime import datetime


def get_path_coordinates(from_date, to_date):
    #archive_url = "http://172.25.11.96/token_archive_log.txt"
    #resource = urllib.request.urlopen(archive_url)
    resource = open("/home/stats_admin/stats_alpha1.2/logs/token_archive_log.txt",
                    'r')
    #resource = open(r"C:\Users\Vasilis Avgoustakis\Desktop\Futurium_Exhibition_Statistics-1.3\logs\token_archive_log.txt",
    #'r')
    # change input dates to datetime objects
    from_date_obj = datetime.strptime(from_date, '%Y-%m-%d')

    to_date_obj = datetime.strptime(to_date, '%Y-%m-%d')

    # read coordinates
    coordinates = pd.read_csv("txt/tokenmap_coordinates.csv")
    coordinates_df = pd.DataFrame(coordinates)
    stations_ids = coordinates_df["Token IDs"]
    stations_x = coordinates_df["x"]
    stations_y = coordinates_df["y"]
    custom_date_range_codes = list()  # list containing all individual armband codes from token daily log

    # go through file and find all bracelet codes within the daterange
    if from_date is not None and to_date is not None:
        with open("./txt/current_query.txt", "w") as query_file:

            for line in resource:
                # turn line from byte obj to string
                str_line = str(line).strip('\n')
                #print(str_line)  ok
                try:
                    # get date as string
                    #str_date = str_line.split("_")[0][2:].strip()
                    str_date = str_line.split("_")[0].strip()
                    #print(str_date) ok
                    # turn date to datetime obj
                    current_line_date_obj = datetime.strptime(str_date, '%d.%m.%Y')

                    # check if current date is within given range
                    if from_date_obj <= current_line_date_obj <= to_date_obj:
                        try:
                            code = str_line.split('"')[1].strip()  # get bracelet code
                            # add code to custom_date_range_codes if not already in there
                            if code not in custom_date_range_codes:
                                custom_date_range_codes.append(code)
                        except:
                            continue
                        try:
                            query_file.write(str_line.strip() + "\n")
                        except:
                            continue
                except:
                    continue

        # add as many indexes to the lists as armbands to make paths of
        x = [[] for i in range(len(custom_date_range_codes))]
        y = [[] for i in range(len(custom_date_range_codes))]
        point_times = [[] for i in range(len(custom_date_range_codes))]

        # print(len(custom_date_range_codes))
        for i in custom_date_range_codes:

            # open reading file with each iteration
            with open("./txt/current_query.txt", "r") as query_file:

                for line in query_file:  # iterate through log again, line by line
                    code = line.split('"')[1].strip()  # get bracelet code
                    if code == i:  # if code from current line matches the code from custom_date_range_codes

                        tokenstation_id = line.split("/")[1].strip()  # get token id in line

                        # get time
                        time = datetime.strptime(line.split("_")[1].strip(), "%H:%M:%S").time()  # get time in line

                        for id in stations_ids:

                            if "Vote" in id:
                                if tokenstation_id == id or tokenstation_id[:-1] + "A/B/C" == id:
                                    if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                            not in x[custom_date_range_codes.index(i)] and stations_y[
                                        coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                            not in y[custom_date_range_codes.index(i)]:
                                        x[custom_date_range_codes.index(i)].append(
                                            stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                        y[custom_date_range_codes.index(i)].append(
                                            stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                        point_times[custom_date_range_codes.index(i)].append(str(time))

                            elif tokenstation_id == id:

                                if stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                        not in x[custom_date_range_codes.index(i)] and stations_y[
                                    coordinates_df[coordinates_df["Token IDs"] == id].index.item()] \
                                        not in y[custom_date_range_codes.index(i)]:
                                    x[custom_date_range_codes.index(i)].append(
                                        stations_x[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                    y[custom_date_range_codes.index(i)].append(
                                        stations_y[coordinates_df[coordinates_df["Token IDs"] == id].index.item()])
                                    point_times[custom_date_range_codes.index(i)].append(str(time))
        resource.close()
        return x, y, point_times

