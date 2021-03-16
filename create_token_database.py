from datetime import datetime
import pandas as pd
from pathlib import Path

# get current date, time and timezone
now = datetime.now()
zone = datetime.astimezone(now).strftime("%z]")
currentDateTime = str(now.strftime("[%d.%b.%Y:%H:%M:%S")+" "+zone)
currentDate = str(now.strftime("%d.%b.%Y"))

#create a csv file with the start date of the recording in his title
tokenStatsFile = open("./database/TokenStatsFrom_%s.csv" % currentDateTime, "wb")
questionStatsFile = open("./database/QuestionStatsFrom_%s.csv" % currentDateTime, "wb")

#make a list for every column you want the Dataframe to have
    #for token scans database
tokenStations = list()
tokenIDs = list()
bereiche = list()

    #for token questions database
tokenQuestionsIDs = list()
tokenQuestionsBereiche = list()
tokenQuestionsNames = list()


# create database for token scans
with open("txt/token_stations.txt", "r") as tokenIndexes:
    indexes = tokenIndexes.readlines()
    for line in indexes:
        #get data
        stationName = line.split("Token")[1].split(";")[0].strip().strip(";")
        tokenID = line.split(";")[0].strip()
        bereich = line.split(";")[1].strip()

        #write data to corresponding lists
        tokenStations.append(stationName)
        tokenIDs.append(tokenID)
        bereiche.append(bereich)



with open("txt/token_abfragen.txt", "r") as tokenQestionsList:
    indexes = tokenQestionsList.readlines()
    for line in indexes:
        #get data
        questionID = line.split(";")[0].strip()[:-5]
        questionBereich = line.split(";")[1].strip()
        questionName = line.split(";")[2].strip()
        #write data to corresponding lists
        tokenQuestionsIDs.append(questionID)
        tokenQuestionsBereiche.append(questionBereich)
        tokenQuestionsNames.append(questionName)


dfData_Scans = {'TokenName' : pd.Series(tokenStations),
          'TokenIDs' : pd.Series(tokenIDs),
          'Bereich' : pd.Series(bereiche),
           'From Data' : currentDate
          }

dfData_Questions = {'Base ID' : pd.Series(tokenQuestionsIDs),
                    'Bereich' : pd.Series(tokenQuestionsBereiche),
                    'Question Names': pd.Series(tokenQuestionsNames),
                    'From Date' : currentDate
                    }

df = pd.DataFrame(dfData_Scans)
df2 = pd.DataFrame(dfData_Questions)
print(df2)


# write Dataframe to file
df.to_csv(tokenStatsFile.name, header= True)
token_database_path = Path(tokenStatsFile.name)

df2.to_csv(questionStatsFile.name, header= True)
questions_database_path = Path(questionStatsFile.name)

#write path of Dataframe csv file as String to seperate txt file for global_variables to read from
path_file = open("txt/tokenLog_database_path.txt", "w")
path_file.write(str(token_database_path))

path_file2 = open("txt/questions_database_path.txt", "w")
path_file2.write(str(questions_database_path))