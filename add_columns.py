from datetime import datetime
import pandas as pd
import global_variables

def addcolumn(file, columnname):
    # get current date, time and timezone
    now = datetime.now()
    #currentDate = str(now.strftime("%d.%b.%Y"))

    #open Stats file and read as dataframe
    data = pd.read_csv(file) #reads csv file as data
    df = pd.DataFrame(data,index= None,) # turns data in Pandas DataFrame Format
    rowCount = int(df.shape[0])-1
    #make a list for every new column to be added to dataframe containing the values for each statistik
    listname = list()


    # add as many empty indexes 0 as rows in the main Dataframe as lines
    for line in df.iterrows():
        if len(listname)<= rowCount:
            listname.append(0)
        else: break

    #add new column as Series to Dataframe and rewrite File
    newColumnString = (columnname) #new column name
    df[newColumnString] = pd.Series(listname) #add new column
    #print(df)

    df.to_csv(file, index= False)# rewrite csv file


#call function give file to add columns to and  column name as string as parameter
addcolumn(global_variables.questionsDatabase,"Answer C" )