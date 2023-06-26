import pandas as pd

def readTokenData(file):
    ##### reads token daily log
    data = pd.read_csv(file) #reads csv file as data
    df = pd.DataFrame(data, index= None) # turns data in Pandas DataFrame Format

    totalScansDict = {} # create dictionary to count daily scans: key = token station name, value = count of scans for the station
    tokenIDs = df.iloc[:,2]

    for id in tokenIDs:
        totalScansDict[id] = 0
    # a list containing all keys from the dictionary
    totalScansKeys = [(k) for k in totalScansDict]

    #open the token log file as rfile
    with open("logs/token_daily_log.txt", "r") as rfile:
        log_data = rfile.readlines()#read lines from file as log data

        for line in log_data:
            currentTokenID = line.split("/")[1].strip()
            for key in totalScansKeys:
                if key == currentTokenID:
                    totalScansDict[key] += 1

        for i in tokenIDs:
            if i in totalScansKeys:
                row = int(list(totalScansDict).index(i))  # set the row number
                value = df.iloc[row, 5]  # access specific value with row and column
                value = int(value) + int(totalScansDict[i])  # add todays dict values to preexisting Values in Dataframe
                df.iloc[row, 5] = value


    #write the updated Dataframe to file (overwrite
    df.to_csv(file, index= False)

def readQuestionsData(file):
    ##### reads token daily log
    data = pd.read_csv(file)  # reads csv file as data
    df = pd.DataFrame(data, index=None)  # turns data in Pandas DataFrame Format

    questionsIDs = df["Base ID"]
    #print(type(questionsIDs))
    answerA = list()
    answerB = list()
    answerC = list()

    # add ass many indexes in each list as number of questionIDs
    for id in questionsIDs:
        row = list(questionsIDs).index(id)
        answerA.append(df.iloc[row, 5])
        answerB.append(df.iloc[row, 6])
        answerC.append(df.iloc[row, 7])

    #print(answerA)

    #open the token log file as rfile
    with open("logs/token_daily_log.txt", "r") as rfile:
        log_data = rfile.readlines()#read lines from file as log data
        for line in log_data:
            questionID = line.split("/")[1].strip()
            for i in questionsIDs:
                if i in questionID and 'A' in questionID:
                    answerA[list(questionsIDs).index(i)] += 1
                elif i in questionID and 'B' in questionID:
                    answerB[list(questionsIDs).index(i)] += 1
                elif i in questionID and 'C' in questionID:
                    answerC[list(questionsIDs).index(i)] += 1

    for id in questionsIDs:
        row = list(questionsIDs).index(id)
        valueA = int(answerA[row])
        valueB = int(answerB[row])# add todays dict values to preexisting Values in Dataframe
        valueC = int(answerC[row])
        df.iloc[row, 5] = valueA
        df.iloc[row, 6] = valueB
        df.iloc[row, 7] = valueC


    # write the updated Dataframe to file (overwrite
    df.to_csv(file, index=False)

#readQuestionsData(file2)