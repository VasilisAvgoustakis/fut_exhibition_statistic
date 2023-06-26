#the goal of this script is to daily update the stats in the the file created by "CreateStatsCsvDatabase.py"##
#by daily reading the new version of access.log.

import pandas as pd
from datetime import datetime
from global_variables import assetDatabase as file
##### reads access log
data = pd.read_csv(file) #reads csv file as data
df = pd.DataFrame(data, index= None) # turns data in Pandas DataFrame Format

totalInteractionsDict = {} # create dictionary to count daily asset recall value: key = asset name, value = count of times name appears in todays log

idles = df.iloc[:,3] #idle name 1darray from df
idles_list = list() # a list containing all idle names
asset_names_list = list() # a list containing all asset names

idle_match = 0 # counting idles calls for currently searched asset name
start_time = datetime.strptime("10:00:00", "%H:%M:%S").time() # count asset recalls from this time onward
end_time = datetime.strptime("18:00:00", "%H:%M:%S").time() # count asset recalls up to this time


for assetName in assetNames:
    totalInteractionsDict[assetName] = 0 # add every asset name as key in the dictionary
    asset_names_list.append(assetName) # add every asset name in asset names list

for idle in idles:
    idles_list.append(idle) # add every idle name in idle names list

#open the access.log file as rfile
with open("logs/access.log", "r") as rfile:
    log_data = rfile.readlines()#read lines from file as log data

    # loop through the asset names
    for assetName in assetNames:
        corresponding_idle_name = idles_list[asset_names_list.index(assetName)] # for every asset name set the coresponding idle name

        #loop through the lines of access.log
        for line in log_data:
            ipAdress = line.split(" ")[0] # get the ip address
            datum = line.split(" ")[3][1:] #get the date
            line_time = datum.split(":")[1] + ":" +datum.split(":")[2] + ":" +datum.split(":")[3] # get the time as string
            time = datetime.strptime(line_time, "%H:%M:%S").time() # turn the time to datetime.strp format
            name = (line.split('"')[1].split("/")[2])[-14:-5] # get the asset name
            get_path = (line.split('"')[1].split("/")[2])[0:] # get the whole asset path


            # check if the access log event is within the right time frame
            if start_time < time and time < end_time:
                if "Idle" in get_path: # if the the current line is about an Idle asset
                    get_path_idle_name = get_path[0:20] #get the idle name
                    if corresponding_idle_name in get_path_idle_name : #if it matches the corresponding idle name for the asset name currently bein looked up
                        idle_match += 1 #add to the idle match counter
                # if the name from access log line matches the currently searched asset name and the idle match is not 0
                if name == assetName and idle_match != 0:
                        # only then count an asset name as recalled having gotten through the cycle Idle name recall and asset name recall
                        totalInteractionsDict[assetName] += 1
                        idle_match = 0 # reset idle match to 0 again

            else:
                continue



    # a list containing all keys from the dictionary
    totalInteractionKeys = [(k) for k in totalInteractionsDict]

    #update Total Interactions Column in Dataframe
    for i in df.loc[:,"Asset Names"]:#add the values from the dictionary with the values of the corresponding Total column to assetName in the dataframe
        if i in totalInteractionKeys:
            row = int(list(totalInteractionsDict).index(i)) #set the row number
            value = df.iloc[row, 5]#access specific value with row and column
            value = int(value) + int(totalInteractionsDict[i])# add todays dict values to preexisting Values in Dataframe
            df.iloc[row, 5] = value


#write the updated Dataframe to file (overwrite
df.to_csv(file, index= False)



