# creates a csv file for the stats read by the daily version of access.log to be saved in
# column headers are (IP , Asset Name, Idle Name, Exhibit Name, Total Interactions,...) but more can be added
#new columns can be added by creating a list for each new column and appending enough indexes to it
from datetime import datetime
import pandas as pd
from pathlib import Path

# get current date, time and timezone
now = datetime.now()
zone = datetime.astimezone(now).strftime("%z]")
currentDateTime = str(now.strftime("[%d.%b.%Y:%H:%M:%S")+" "+zone)
currentDate = str(now.strftime("%d.%b.%Y"))

#create a csv file with the start date of the recording in his title
statsFile = open("./VideoStatsFrom_%s.csv" % currentDateTime, "wb")


#make a list for every column you want the Dataframe to have
    #main lists mapping IPs and asset Names
ipAddresses = list()
assetNames = list()
idles = list()
expo_names = list()

    #statistics list for every column containing the values for each statistik
#totalInteractions = list()

#read IPs and Asset names from AssetNames.txt. AssetNames.txt contains all the exhibits mapped to their asset name, idle name and exhibit name
with open("txt/video_player_list.txt", "r") as mapedData:
    map = mapedData.readlines()
    for line in map:
        ipAdress = line.split(";")[0]
        assetName = line.split(";")[1].strip()
        idle_name = line.split(";")[2].strip()
        expo_name = line.split(";")[3].strip()
        ipAddresses.append(ipAdress)
        assetNames.append(assetName)
        idles.append(idle_name)
        expo_names.append(expo_name)

dfData = {'IP' : pd.Series(ipAddresses),
          'Asset Names' : pd.Series(assetNames),
          'Idles Names' : pd.Series(idles),
          'Exponate' : pd.Series(expo_names)}


df = pd.DataFrame(dfData)
print(df)


# write Dataframe to file
df.to_csv(statsFile.name, header= True)
database_path = Path(statsFile.name)

#write path of Dataframe csv file as String to seperate txt file for global_variables to read from
path_file = open("logs/assetLog_database_path.txt", "w")
path_file.write(str(database_path))
print(database_path)