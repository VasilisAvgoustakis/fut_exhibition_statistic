import pandas as pd
import numpy as np
from dash import dcc
from dash import html
import os
import base64
import global_variables as gv
import plotly.graph_objs as go
from plotly.subplots import make_subplots
from datetime import datetime as dt
import random

def plot_total_scans_tk(data):
    # do the right processing to ploted data according to selected graph
    df = pd.DataFrame(data)
    df.columns = ['Token Station', 'Name', 'Area', 'Scans', 'Archived']

    # store data for CSV export
    gv.csv_file_data = df
    #print(gv.csv_file_data)

    #print(df)
    df_human = df[(df['Area'] == 'human') &
                  (df['Archived'].isna())]
    df_tech = df[(df['Area'] == 'technology') &
                  (df['Archived'].isna())]
    df_nature = df[(df['Area'] == 'nature') &
                   (df['Archived'].isna())]
    df_interactive = df[(df['Area'] == 'interactive') &
                     (df['Token Station'] != 'gtTokenGenetics0') &
                     (df['Archived'].isna())]
    df_archived_human = df[(df['Archived'].notna()) & (df['Area'] == 'human')]
    df_archived_tech = df[(df['Archived'].notna()) & (df['Area'] == 'technology')]
    df_archived_nature = df[(df['Archived'].notna()) & (df['Area'] == 'nature')]
    df_archived_interactive = df[(df['Archived'].notna()) & (df['Area'] == 'interactive')]

    # bar
    fig = go.Figure(data=[
        go.Bar(name='Mensch', x=df_human['Name'] if df_human['Name'].notnull().any() else df_human['Token Station'], y=df_human['Scans']),
        go.Bar(name='Technik', x=df_tech['Name'] if df_tech['Name'].notnull().any() else df_tech['Token Station'], y=df_tech['Scans']),
        go.Bar(name='Natur', x=df_nature['Name'] if df_nature['Name'].notnull().any() else df_nature['Token Station'], y=df_nature['Scans']),
        go.Bar(name='Interaktiv', x=df_interactive['Name'] if df_interactive['Name'].notnull().any() else df_interactive['Token Station'], y=df_interactive['Scans']),
        go.Bar(name='Archived Human', x=df_archived_human['Name'] if df_archived_human['Name'].notnull().any() else df_archived_human['Token Station'], y=df_archived_human['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Technik', x=df_archived_tech['Name'] if df_archived_tech['Name'].notnull().any() else df_archived_tech['Token Station'], y=df_archived_tech['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Natur', x=df_archived_nature['Name'] if df_archived_nature['Name'].notnull().any() else df_archived_nature['Token Station'], y=df_archived_nature['Scans'], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Interaktiv', x=df_archived_interactive['Name'] if df_archived_interactive['Name'].notnull().any() else df_archived_interactive['Token Station'], y=df_archived_interactive['Scans'], text='Archiviert', textposition='auto'),
    ]
    )

    fig.update(layout_title_text=gv.query_total_scans_tk_msg ,
           layout_showlegend=True)

    # pie

    pie_mensch = go.Figure(go.Pie(name='Mensch', 
                            labels=df_human['Name'] if df_human['Name'].notnull().any() else df_human['Token Station'], 
                            values=df_human['Scans'],
                            textinfo='percent+value+label',
                            texttemplate='%{value} Scans, %{percent}'))
    pie_tech = go.Figure(go.Pie(name='Technik', 
                            labels=df_tech['Name'] if df_tech['Name'].notnull().any() else df_tech['Token Station'], 
                            values=df_tech['Scans'],
                            textinfo='percent+value+label',
                            texttemplate='%{value} Scans, %{percent}'))
    pie_nature = go.Figure(go.Pie(name='Natur', 
                            labels=df_nature['Name'] if df_nature['Name'].notnull().any() else df_nature['Token Station'], 
                            values=df_nature['Scans'],
                            textinfo='percent+value+label',
                            texttemplate='%{value} Scans, %{percent}'))
    pie_interactive = go.Figure(go.Pie(name='Interaktiv', 
                            labels=df_interactive['Name'] if df_interactive['Name'].notnull().any() else df_interactive['Token Station'], 
                            values=df_interactive['Scans'],
                            textinfo='percent+value+label',
                            texttemplate='%{value} Scans, %{percent}'))

    # Tune layout and hover info
    pie_mensch.update(
        layout_title_text=gv.query_total_scans_tk_msg_pie,
        layout_showlegend=True)
    
    pie_tech.update(
        layout_title_text=gv.query_total_scans_tk_msg_pie,
        layout_showlegend=True)
    
    pie_nature.update(
        layout_title_text=gv.query_total_scans_tk_msg_pie,
        layout_showlegend=True)
    
    pie_interactive.update(
        layout_title_text=gv.query_total_scans_tk_msg_pie,
        layout_showlegend=True)

    

    return fig, pie_mensch, pie_tech, pie_nature, pie_interactive

def plot_avg_scans(data):
    df = pd.DataFrame(data)
    df.columns = ['Token Station', 'Name', 'Area', 'Scans', 'From', 'Up to', 'Months passed', 'Archived', 'Average per Month']

    # store data for CSV export
    gv.csv_file_data = df


    df_human = df[(df['Area'] == 'human') &
                  (df['Archived'].isna())]
    df_tech = df[(df['Area'] == 'technology') &
                  (df['Archived'].isna())]
    df_nature = df[(df['Area'] == 'nature') &
                   (df['Archived'].isna())]
    df_interactive = df[(df['Area'] == 'interactive') &
                     (df['Token Station'] != 'gtTokenGenetics0') &
                     (df['Archived'].isna())]
    df_archived_human = df[(df['Archived'].notna()) & (df['Area'] == 'human')]
    df_archived_tech = df[(df['Archived'].notna()) & (df['Area'] == 'technology')]
    df_archived_nature = df[(df['Archived'].notna()) & (df['Area'] == 'nature')]
    df_archived_interactive = df[(df['Archived'].notna()) & (df['Area'] == 'interactive')]

    x_axis = 'Name'
    y_axis = 'Average per Month'

    fig = go.Figure(data=[
        go.Bar(name='Mensch', x=df_human[x_axis], y=df_human[y_axis],),
        go.Bar(name='Technik', x=df_tech[x_axis], y=df_tech[y_axis]),
        go.Bar(name='Natur', x=df_nature[x_axis], y=df_nature[y_axis]),
        go.Bar(name='Interaktiv', x=df_interactive[x_axis], y=df_interactive[y_axis]),
        go.Bar(name='Archived Human', x=df_archived_human[x_axis], y=df_archived_human[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Technik', x=df_archived_tech[x_axis], y=df_archived_tech[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Natur', x=df_archived_nature[x_axis], y=df_archived_nature[y_axis], text='Archiviert', textposition='auto'),
        go.Bar(name='Archived Interaktiv', x=df_archived_interactive[x_axis], y=df_archived_interactive[y_axis], text='Archiviert', textposition='auto'),
    ]
    )
    fig.update(layout_title_text=gv.avg_scans_pro_monat_msg,
           layout_showlegend=True)

    # pie

    pie_mensch = go.Figure(go.Pie(name='Mensch', 
                            labels=df_human['Name'], 
                            values=df_human['Average per Month'],
                            textinfo='percent+value+label',
                            texttemplate='%{value:.0f} Scans, %{percent}'))
    pie_tech = go.Figure(go.Pie(name='Technik', 
                            labels=df_tech['Name'], 
                            values=df_tech['Average per Month'],
                            textinfo='percent+value+label',
                            texttemplate='%{value:.0f} Scans, %{percent}'))
    pie_nature = go.Figure(go.Pie(name='Natur', 
                            labels=df_nature['Name'], 
                            values=df_nature['Average per Month'],
                            textinfo='percent+value+label',
                            texttemplate='%{value:.0f} Scans, %{percent}'))
    pie_interactive = go.Figure(go.Pie(name='Interaktiv', 
                            labels=df_interactive['Name'], 
                            values=df_interactive['Average per Month'],
                            textinfo='percent+value+label',
                            texttemplate='%{value:.0f} Scans, %{percent}'))

    # Tune layout and hover info
    pie_mensch.update(
        layout_title_text=gv.avg_scans_pro_monat_msg_pie,
        layout_showlegend=True)
    
    pie_tech.update(
        layout_title_text=gv.avg_scans_pro_monat_msg_pie,
        layout_showlegend=True)
    
    pie_nature.update(
        layout_title_text=gv.avg_scans_pro_monat_msg_pie,
        layout_showlegend=True)
    
    pie_interactive.update(
        layout_title_text=gv.avg_scans_pro_monat_msg_pie,
        layout_showlegend=True)

    

    return fig, pie_mensch, pie_tech, pie_nature, pie_interactive

def plot_total_per_region(data):
    df = pd.DataFrame(data)
    df.columns = ['Area', 'Number of Stations', 'Total Scans']

    # store data for CSV export
    gv.csv_file_data = df

    # Create a pie chart
    labels = df.iloc[:, 0].astype(str) + " - " + df.iloc[:, 1].astype(str) + " Stations"
    values=df.iloc[:, 2]
    
    fig = go.Figure(data=[go.Pie(labels=labels, 
                                 values=values,
                                 textposition='auto', 
                                 textinfo='percent+value+label',
                                 texttemplate=' %{value} Scans, %{percent}'
                                 )])
    
    fig.update(layout_title_text=gv.total_scans_per_region_msg,
           layout_showlegend=True)
    return fig

def plot_avg_per_region_per_station(data):
    df = pd.DataFrame(data)
    df.columns = ['Area', 'Number of Stations', 'Total Scans', 'Average per Station']

    # store data for CSV export
    gv.csv_file_data = df

    # Create a pie chart
    labels = df.iloc[:, 0].astype(str) + " - " + df.iloc[:, 1].astype(str) + " Stations"
    values=df.iloc[:, 3]
    
    fig = go.Figure(data=[go.Pie(labels=labels, 
                                 values=values,
                                 textposition='auto', 
                                 textinfo='percent+value+label',
                                 texttemplate=' %{value:.1f} Scans, %{percent}'
                                 )])
    
    fig.update(layout_title_text=gv.avg_scans_per_region_per_station_msg,
           layout_showlegend=True)
    return fig

def plot_avg_time_per_visitor(data):
    df = pd.DataFrame(data)
    df.columns = ['Technik', 'Mensch', 'Natur', 'Interaktiv']
    
    # store data for CSV export
    gv.csv_file_data = df.iloc[:-1] #exclude last row containg the #of stations per region

    # Create a pie chart
    # the 1st row of the data is the time in minutes
    # the 2nd row of the data is the number of station per Region
    labels = df.columns.astype(str) + " - " + df.iloc[1].astype(int).astype(str) + " Stations"
    values=df.iloc[0]

    fig = go.Figure(data=[go.Pie(labels=labels, 
                                 values=values,
                                 textposition='auto', 
                                 textinfo='percent+value+label',
                                 texttemplate='%{value} Min, %{percent}'
                                 )])
    
    fig.update(layout_title_text=gv.avg_time_per_visitro_msg,
           layout_showlegend=True)

    return fig

def plot_visitors_per_day(data):
    df = pd.DataFrame(data)
    df.columns = ['Date', 'Total Armbands', 'ZM Scans']

    # store data for CSV export
    gv.csv_file_data = df

    total_visitors = df['Total Armbands'].sum()
    total_zm_scans = df['ZM Scans'].sum()

    x_axis = df['Date']
    y_axis1 = df['Total Armbands']
    y_axis2 = df['ZM Scans']
    

    # Create a Figure
    fig = go.Figure()

    # Creating trace for the first y-axis
    fig.add_trace(go.Bar(
        x=x_axis,
        y=y_axis1,
        name='Besucher',
    ))

    #Create trace for 2nd y-axis
    fig.add_trace(go.Bar(
        x=x_axis,
        y=y_axis2,
        name='ZM Scans',
    ))

    # Adding Annotations
    fig.add_annotation(
        x=0,
        y=1,
        xref='paper',
        yref='paper',
        text=f"Gesamt Besucher im selektierten Zeitraum: {total_visitors}",
        showarrow=False
    )
    fig.add_annotation(
        x=0,
        y=0.95,
        xref='paper',
        yref='paper',
        text=f"Gesamt ZM Scans im selektierten Zeitraum: {total_zm_scans}",
        showarrow=False,
    )

    fig.add_annotation(
        x=0,
        y=0.90,
        xref='paper',
        yref='paper',
        text=f"ZM Scans zu Besucher Quote: {round((total_zm_scans*100)/total_visitors,1)}%",
        showarrow=False,
    )

    fig.update(layout_title_text=gv.total_visitors_per_day_msg,
           layout_showlegend=True)

    return fig

def plot_avg_scans_per_visitor(data):
    df = pd.DataFrame(data)
    df.columns = ['Area', 'Total Scans', 'Total Visitors', 'avg_per_visitor_per_area', 'Total Visitors all regions']

    # store data for CSV export
    gv.csv_file_data = df

    labels = df['Area']
    values = df['avg_per_visitor_per_area']

    total_scans_all_regions = df['Total Scans'].sum()
    total_visitors_all_areas = df['Total Visitors all regions'][0]

    fig = go.Figure(data=[
        go.Pie(labels=labels, 
               values=values,
               textposition='auto',
               textinfo='percent+value+label',
               texttemplate='%{label}: %{value:.1f} Scans, %{percent}')
    ])

    # Adding Annotations
    fig.add_annotation(
        x=0,
        y=1,
        xref='paper',
        yref='paper',
        text=f"Gesamt Scans in allen Denkräume: {total_scans_all_regions}",
        showarrow=False
    )
    fig.add_annotation(
        x=0,
        y=0.95,
        xref='paper',
        yref='paper',
        text=f"Gesamte Besucher in alle Denkräume: {total_visitors_all_areas}",
        showarrow=False,
    )

    fig.add_annotation(
        x=0,
        y=0.90,
        xref='paper',
        yref='paper',
        text=f"Gesamt Scans pro Gesamt besucher: {round(total_scans_all_regions/total_visitors_all_areas,1)}",
        showarrow=False,
    )

    fig.update(layout_title_text=gv.avg_scans_per_visitor_msg,
           layout_showlegend=True)
    
    return fig

def plot_vote_scans_per_question(data):
    df = pd.DataFrame(data)
    df.columns = ['Station', 'Name', 'Total Scans']

    # store data for CSV export
    gv.csv_file_data = df

    # Assume that the station group identifier is all but the last character of the 'Station' string
    df['StationGroup'] = df['Station'].str[:-1]

    # Create a new DataFrame with the correct layout
    df_pivot = df.pivot_table(index='StationGroup', 
                            columns=df.groupby('StationGroup').cumcount().add(1), 
                            values=['Name', 'Total Scans'], 
                            aggfunc='first').sort_index(level=1, axis=1)

    # Flatten the MultiIndex in columns and create a new column set
    df_pivot.columns = [f'{x}{y}' for x, y in df_pivot.columns]

    # Reset index to turn the indices into columns
    df_pivot.reset_index(inplace=True)

    # Set the option to display all columns (None means unlimited)
    #pd.set_option('display.max_columns', None)
    
    #print(df_pivot)


    x_axis = df_pivot['StationGroup']
    x1= df_pivot['Name1']
    x2= df_pivot['Name2']
    x3= df_pivot['Name3']
    y1 = df_pivot['Total Scans1']
    y2 = df_pivot['Total Scans2']
    y3 = df_pivot['Total Scans3']

    #Create figure
    fig = go.Figure()

    for index, row in df_pivot.iterrows():
        # Add an empty bar to create a gap
        fig.add_trace(go.Bar(x=[x_axis.iloc[index]], y=[0]))
        
        fig.add_trace(
            go.Bar(x=[x1.iloc[index]], y=[y1.iloc[index]], marker_color='blue', name=x_axis.iloc[index])
            )
        fig.add_trace(
            go.Bar(x=[x2.iloc[index]], y=[y2.iloc[index]], marker_color='green', name=x_axis.iloc[index])
            )
        fig.add_trace(
            go.Bar(x=[x3.iloc[index]], y=[y3.iloc[index]], marker_color='red', name=x_axis.iloc[index])
            )
        
    

    fig.update(layout_title_text=gv.vote_scans_per_question_msg,
           layout_showlegend=False)

    return fig

def plot_probable_path(data):
    #print(data)
    df = pd.DataFrame(data)
    df.columns = ['code', 'station', 'name', 'date', 'time', 'x_coord', 'y_coord']

    # store data for CSV export
    gv.csv_file_data = df

# segregate the data by each unique armband code, sort it by time, 
# and then count the transitions between stations in the transtion_count dictionary.

    # Initialize an empty dictionary to hold transition counts
    transition_count = {}

    # Create a list of unique (band_code, date) tuples
    unique_combinations = pd.unique(list(zip(df['code'], df['date'])))

    # Iterate through each unique armband code (unique regarding code and date combinations)
    for band_code, scan_date in unique_combinations:
        subset = df[(df['code'] == band_code) & (df['date'] == scan_date)]
        prev_station = None

        # Iterate through each row in the subset DataFrame
            #The _ is a convention to indicate that the index is not used in the loop. 
            # The row variable contains the data of each row as a Series, and you can access its elements
            # as you would with a Python dictionary.# 
        for _, row in subset.iterrows():
            current_station = row['name']
            
            # If we have a 'previous station', we can count a transition
            if prev_station is not None:
                if (prev_station, current_station) not in transition_count:
                    transition_count[(prev_station, current_station)] = 1 # set to 1 and not zero since first occurence should also count
                transition_count[(prev_station, current_station)] += 1
            
            prev_station = current_station
    
# calculate the Markov's transition Matrix
    # Create the transition matrix
    stations = df['name'].unique()
    n = len(stations)
    transition_matrix = np.zeros((n, n)) # matrix has n rows and n cols all set to 0

    # populate the matrix with the transition count of every station pair from the transition_count dict.
    # iterate over all pairs of stations (from_station, to_station).
    for i, from_station in enumerate(stations):
        for j, to_station in enumerate(stations):
            transition_matrix[i, j] = transition_count.get((from_station, to_station), 0) #  If no such transition exists in transition_count, it defaults to 0.
 

    # Normalize the transition matrix  goal is to make the sum of each row equal to 1
    # calculate the sum of each row
    row_sums = transition_matrix.sum(axis=1)
    #  find the indices of zero elements in the array row_sums.
    zero_rows = np.where(row_sums == 0)[0]
    row_sums[zero_rows] = 1  # Avoid division by zero for rows that sum to zero

    # divide each element of each row by the corresponding row sum to tranform it to propability
    transition_matrix = transition_matrix / row_sums[:, np.newaxis]

# add the image to the graph & initialize figure
    with open(os.getcwd() + "/tokenmap.png", "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode()

    # Add the prefix that plotly will want when using the string as source
    encoded_image = "data:image/png;base64," + encoded_string

    #Initialize figure
    fig = go.Figure()

    # Add image
    img_width = 2380
    img_height = 1992
    fig.add_layout_image(
        x=0,
        sizex=img_width,
        y=0,
        sizey=img_height,
        xref="x",
        yref="y",
        opacity=1.0,
        layer="below",
        source=encoded_image,
    )

    fig.update_xaxes(showgrid=False, range=(0, img_width))
    fig.update_yaxes(showgrid=False, scaleanchor='x', range=(img_height, 0))

# Map station to coordinates
    # Create a dictionary to map station IDs to their x and y coordinates
    coord_dict = {row['name']: (row['x_coord'], row['y_coord']) for _, row in df.drop_duplicates('name').iterrows()}
    #print(coord_dict)
# Identify the most common "first station" by looking at the start_state for each unique armband code in your dataset. 
    most_common_start = df.groupby('code').first()['name'].value_counts().idxmax()

    # Get its index in the 'stations' array
    most_common_start_idx = np.where(stations == most_common_start)[0][0]

    # Initialize
    visited_stations = set()
    current_station_idx = most_common_start_idx
    path = [most_common_start]

    new_station_visited = True  # Initialize flag to True to enter the loop


    while len(visited_stations) < len(stations) and new_station_visited:
        new_station_visited = False  # Reset flag at the beginning of each iteration
        if current_station_idx not in visited_stations:
            visited_stations.add(current_station_idx)  # Add the newly visited station to the visited list
        # sort the indices of the transition probabilities in descending order
        sorted_indices = np.argsort(-transition_matrix[current_station_idx, :])
        
        for next_station_idx in sorted_indices:
            next_station = stations[next_station_idx]
            #catch case of Vote stations that all have same coordinates
            #if "Vote" in next_station: next_station = next_station[:-1]
            # only add station in path if it has not already been visited and it is not the Zukunfstsmachine or delete station
            if next_station not in path and (next_station != "Zukunftsmaschine" and next_station !="Delete Armband"):
                path.append(next_station)
                new_station_visited = True  # Set flag to True since a new station was visited

                break # Exit the inner loop if you find a station that is not in the path
        
        # Move to the next station (next_station_idx) is set to the station just visited when the above loop was interupted
        current_station_idx = next_station_idx
    

        if len(visited_stations) == len(stations) or not new_station_visited:
            break  # Break the loop when all stations have been visited

    # add the future machine at the end of the path manually for logical concistensy
    path.append("Zukunftsmaschine")

    # Function to interpolate points along the line
    def interpolate_points(x1, y1, x2, y2, num_arrows=3):
        return [(x1 + i*(x2-x1)/num_arrows, y1 + i*(y2-y1)/num_arrows) for i in range(1, num_arrows)]


    # Draw lines for the most probable path
    for i in range(len(path) - 1):
        
        # x1, y1 = 0.0, 0.0
        # x2, y2 = 0.0, 0.0
        
        #if "Vote" in path[i]:
        #    x1, y1 = coord_dict[str(path[i])+'A']
        #     from_station = str(path[i]+'A')
        # if "Vote" in path[i+1]:
        #     x2, y2 = coord_dict[str(path[i+1])+'A']
        #     to_station = str(path[i+1]+'A')
        #if "Vote" not in path[i] : # again catch the case of the variable name but same coordinates for Vote stations
        x1, y1 = coord_dict[path[i]]
        from_station = path[i]
        #if "Vote" not in path[i+1]:
        x2, y2 = coord_dict[path[i+1]]
        to_station = path[i+1]
        

        # Add points for the stations
        fig.add_trace(go.Scatter(x=[coord_dict[from_station][0]], y=[coord_dict[from_station][1]],
                                mode='markers',
                                marker=dict(size=10),
                                name=path[i]
                                ))

        # Add a line trace between the stations (optional)
        # fig.add_trace(go.Scatter(x=[x1, x2], y=[y1, y2],
        #                         mode='lines',
        #                         line=dict(width=1, color='red'),
        #                         name=f'Line from {path[i]} to {path[i+1]}'))

        # # Add an arrow annotation at the endpoint of the line
        fig.add_annotation(
            x=x2, y=y2,
            ax=x1, ay=y1,
            xref='x', yref='y',
            axref='x', ayref='y',
            showarrow=True,
            arrowhead=1,
            arrowsize=2,
            arrowwidth=1,
            arrowcolor="red"
        )

        # Add arrow annotations along the line
        for point in interpolate_points(x1, y1, x2, y2, num_arrows=3):
            fig.add_annotation(
                x=point[0], y=point[1],
                ax=point[0] - (x2 - x1) / 20,  # Adjust these values as necessary for arrow direction
                ay=point[1] - (y2 - y1) / 20,  # Adjust these values as necessary for arrow direction
                xref='x', yref='y',
                axref='x', ayref='y',
                showarrow=True,
                arrowhead=1,
                arrowsize=2,
                arrowwidth=1,
                arrowcolor="red"
            )

    # Add last trace for ZM
    fig.add_trace(go.Scatter(x=[coord_dict[path[-1]][0]], y=[coord_dict[path[-1]][1]],
                            mode='markers',
                            marker=dict(size=10),
                            name=path[-1]
                            ))
    
    fig.update(layout_title_text=gv.probable_path_msg,
           layout_showlegend=True)

    return fig

def derive_random_paths(data):
    df = pd.DataFrame(data)
    df.columns = ['code', 'station', 'name', 'date', 'time', 'x_coord', 'y_coord']

# pick the data for 100 distinct armbands at random, sort it by time, 
    # create new df for 100 random paths
    columns = ['code', 'station', 'name', 'date', 'time', 'x_coord', 'y_coord']
    random_paths = pd.DataFrame(columns=columns)
    
    #print(type(random_paths))    
    
    # Create a list of unique (band_code, date) tuples
    unique_combinations = pd.unique(list(zip(df['code'], df['date'])))

    # Shuffle the list of unique combinations in random order
    random.shuffle(unique_combinations)

    # Iterate through each unique armband code
    for band_code, scan_date in unique_combinations:
        subset = df[(df['code'] == band_code) & (df['date'] == scan_date)]

        #print(type(subset))
        # print(subset)

        # consider only paths with more than 10 different scans
        if len(subset) > 10 and len(random_paths['code'].unique()) <= 10:
            random_paths = pd.concat([random_paths, subset], ignore_index=True)
        
    # print(len(random_paths['code'].unique()))    
    # print(random_paths)

    # store data for CSV export
    gv.csv_file_data = random_paths
    

# add the image to the graph & initialize figure
    with open(os.getcwd() + "/tokenmap.png", "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode()

    # Add the prefix that plotly will want when using the string as source
    encoded_image = "data:image/png;base64," + encoded_string

    # #Initialize figure
    fig = go.Figure()

    # Add image
    img_width = 2380
    img_height = 1992
    fig.add_layout_image(
        x=0,
        sizex=img_width,
        y=0,
        sizey=img_height,
        xref="x",
        yref="y",
        opacity=1.0,
        layer="below",
        source=encoded_image,
    )

    fig.update_xaxes(showgrid=False, range=(0, img_width))
    fig.update_yaxes(showgrid=False, scaleanchor='x', range=(img_height, 0))

# Map station to coordinates
    # Create a dictionary to map station IDs to their x and y coordinates
    gv.coord_dict = {row['name']: (row['x_coord'], row['y_coord']) for _, row in random_paths.drop_duplicates('name').iterrows()}

    # Function to interpolate points along the line
    #def interpolate_points(x1, y1, x2, y2, num_arrows=3):
        #return [(x1 + i*(x2-x1)/num_arrows, y1 + i*(y2-y1)/num_arrows) for i in range(1, num_arrows)]


    # Draw lines for the most probable path
    # for i in range(len(path) - 1):
        
    #     #if "Vote" not in path[i] : # again catch the case of the variable name but same coordinates for Vote stations
    #     x1, y1 = coord_dict[path[i]]
    #     from_station = path[i]
    #     #if "Vote" not in path[i+1]:
    #     x2, y2 = coord_dict[path[i+1]]
    #     to_station = path[i+1]
        

    #     # Add points for the stations
    #     fig.add_trace(go.Scatter(x=[coord_dict[from_station][0]], y=[coord_dict[from_station][1]],
    #                             mode='markers',
    #                             marker=dict(size=10),
    #                             name=path[i]
    #                             ))


    #     # # Add an arrow annotation at the endpoint of the line
    #     fig.add_annotation(
    #         x=x2, y=y2,
    #         ax=x1, ay=y1,
    #         xref='x', yref='y',
    #         axref='x', ayref='y',
    #         showarrow=True,
    #         arrowhead=1,
    #         arrowsize=2,
    #         arrowwidth=1,
    #         arrowcolor="red"
    #     )

    #     # Add arrow annotations along the line
    #     for point in interpolate_points(x1, y1, x2, y2, num_arrows=3):
    #         fig.add_annotation(
    #             x=point[0], y=point[1],
    #             ax=point[0] - (x2 - x1) / 20,  # Adjust these values as necessary for arrow direction
    #             ay=point[1] - (y2 - y1) / 20,  # Adjust these values as necessary for arrow direction
    #             xref='x', yref='y',
    #             axref='x', ayref='y',
    #             showarrow=True,
    #             arrowhead=1,
    #             arrowsize=2,
    #             arrowwidth=1,
    #             arrowcolor="red"
    #         )

    # Add last trace for ZM
    #fig.add_trace(go.Scatter(x=[coord_dict[path[-1]][0]], y=[coord_dict[path[-1]][1]],
                            # mode='markers',
                            # marker=dict(size=10),
                            # name=path[-1]
                            # ))
    
    # fig.update(layout_title_text=gv.random_paths_msg,
    #        layout_showlegend=True)

    return fig

plotters =[plot_total_scans_tk, plot_avg_scans, 
           plot_total_per_region, 
           plot_avg_per_region_per_station,
           plot_avg_time_per_visitor,
           plot_visitors_per_day,
           plot_avg_scans_per_visitor,
           plot_vote_scans_per_question,
           plot_probable_path,
           derive_random_paths
           ] #test