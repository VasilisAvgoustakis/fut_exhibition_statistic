import datetime
from datetime import date
import dash
from dash import Dash, html, dcc, callback, Output, Input, State
from dash.exceptions import PreventUpdate
import plotly.graph_objs as go
import plotly.express as px
import ast
from mysql.connector.cursor import MySQLCursor
from mysql.connector import pooling
import pandas as pd
import global_variables as gv
import queries as qrs
from plotting import plotters
import importlib

gv.logging.info("%s Dash server process is running...")

# variables

current_month = date.today().month
external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

# DB code

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
        pool_name="db_pool_dash_app",
        pool_size=5,
        pool_reset_session =True,
        **dbconfig
    )

    # get pool name
    pool_name  = db_connection_pool.pool_name
    
except Exception as e:
        gv.logging.exception("Exception while creating Pool for Dash_app: %s", e)


try:
    # Retrieve a connection from the pool
    connection = db_connection_pool.get_connection() 
    
    db_Info = connection.get_server_info()

except ValueError as e:
    gv.logging.error("Error occurred while establishing connection from pool %s: %s", pool_name, e)
except Exception as e:
    # Log or handle the exception
    gv.logging.exception("Exception while establishing connection from pool %s: %s", pool_name, e)

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


# Dash App
app = Dash(__name__, external_stylesheets=external_stylesheets)
server = app.server

# List containing tha categories of graphs that can be displayed by the app
graph_types = ['Gesamtscans pro Token-Station (ALLE)']
# var contains min and max default dates
gv.start_date_string = '2020-09-23'
gv.end_date_string = gv.yesterday.strftime('%Y-%m-%d')


app.layout = html.Div([
    html.H2('Ausstellung Statistik'),
    dcc.Dropdown(
        id='dropdown',
        options=[{'label': i, 'value': i} for i in graph_types],
        value='Gesamtscans pro Token-Station (ALLE)'
    ),
    dcc.DatePickerRange(
                id='my-date-picker-range',
                min_date_allowed=date(2020, 9, 23),
                max_date_allowed=gv.yesterday,
                initial_visible_month=date.today(),
                display_format="DD.MM.YYYY",
                updatemode='bothdates',
                clearable= True
                ),

    html.Div(id='output-container-date-picker-range'),
    # dcc.Slider(
    #     id='slider',
    #     min=0,
    #     step=1,
    #     value=0,
    #     updatemode='mouseup'
    # ),
    # html.Div(id='slider-output-container'),
    html.Button('submit', id='submit-dates', n_clicks=0 ),
    # I frame for all graph types except
    # html.Iframe(id='selected-graph-type',
    #             style={"height": "900px", "width": "100%"}, hidden=True),
    html.Div(dcc.Graph(id='graph-content', style={"height": "200%", "width": "100%"}))
])


# functions gets the right query text when user selects the corresponding graph type from the dropdown
def fetch_data_from_db(query, date_values):
    
    cursor.execute(query, date_values)
    data = cursor.fetchall()
    return data

@app.callback(
    Output('graph-content', 'figure'),
    
    [Input('submit-dates', 'n_clicks'),
        Input('dropdown', 'value')]
)
def update_graph(nclick, graph_name):

    sel_graph_index = graph_types.index(graph_name)
    # get the query with the same list index as the selected graph type
    selected_query = qrs.queries[sel_graph_index]
    #get the right date values sequences for the query
    date_values = qrs.date_strings_sequences[sel_graph_index]
    # fetch the right data
    data = fetch_data_from_db(selected_query, date_values)

    # plot the data using the right 'plotter' function
    fig = plotters[sel_graph_index](data)
    
    
    return fig


#     graphs_path = r"C:\Users\Vasilis Avgoustakis\Desktop\Futurium_Exhibition_Statistics-1.3\html"

#     if value == 'Visitors per day':
#         url = "http://172.25.11.96/exhibition_visitors_per_day.html"
#         #path = "/var/www/html/exhibition_visitors_per_day.html"
#         return url, False, True, True, True

#     if value == 'Average Scans per Station/Month Bar':
#         url = "http://172.25.11.96/average_tokenScans_perStation_perMonth_bar.html"
#         path = "/var/www/html/average_tokenScans_perStation_perMonth_bar.html"
#         return url, False, True, True, True

#     if value == 'Average Scans per Station/Month Pie':
#         url = "http://172.25.11.96/average_tokenScans_perStation_perMonth_pie.html"
#         path = "/var/www/html/average_tokenScans_perStation_perMonth_pie.html"
#         return url, False, True, True, True

#     if value == 'Questions':
#         url = "http://172.25.11.96/questionsBar_Scans.html"
#         path = "/var/www/html/questionsBar_Scans.html"
#         return url, False, True, True, True

#     if value == 'Avg Time/Region':
#         url = "http://172.25.11.96/Region_Average_TimesperArmband.html"
#         path = "/var/www/html/Region_Average_TimesperArmband.html"
#         return url, False, True, True, True

#     if value == 'Region popularity':
#         url = "http://172.25.11.96/token_popularity_per_region.html"
#         path = "/var/www/html/token_popularity_per_region.html"
#         return url, False, True, True, True

#     if value == 'Total Scans per Region':
#         url = "http://172.25.11.96/token_scans_per_region.html"
#         path = "/var/www/html/token_scans_per_region.html"
#         return url, False, True, True, True

#     if value == 'Total Scans per Station Bar':
#         url = "http://172.25.11.96/total_tokenScans_perStation_bar.html"
#         path = "/var/www/html/total_tokenScans_perStation_bar.html"
#         return url, False, True, True, True

#     if value == 'Total Scans per Station Pie':
#         url = "http://172.25.11.96/total_tokenScans_perStation_pie.html"
#         path = "/var/www/html/total_tokenScans_perStation_pie.html"
#         return url, False, True, True, True

#     if value == 'Visitor Paths':
#         url = "http://172.25.11.96/exhibition_paths.html"
#         path = "/var/www/html/exhibition_paths.html"
#         return None, True, False, False, False


@app.callback(
    Output('output-container-date-picker-range', 'children'),
    [Input('my-date-picker-range', 'start_date'),
     Input('my-date-picker-range', 'end_date')]
)
def update_output_date_picker(start_date=gv.start_date_string, end_date=gv.end_date_string):

    string_prefix = 'You have selected: '
    #print(start_date)
    if start_date is not None:
        start_date_object = date.fromisoformat(start_date)
        #update global variable start date
        gv.start_date_string = start_date_object.strftime('%Y-%m-%d')

        # set local string var for start date
        local_start_date_str = start_date_object.strftime('%B-%d, %Y')
        string_prefix = string_prefix + 'Start Date: ' + local_start_date_str + ' | '
    if end_date is not None:
        end_date_object = date.fromisoformat(end_date)
        # update global variable end date
        gv.end_date_string = end_date_object.strftime('%Y-%m-%d')

        # set local string var for end date
        local_end_date_str = end_date_object.strftime('%B-%d, %Y')
        string_prefix = string_prefix + 'End Date: ' + local_end_date_str
    else:
        
        gv.start_date_string = '2020-09-23'
        
        gv.end_date_string = gv.yesterday.strftime('%Y-%m-%d')  

    # Reload the queries module to reflect the changes in other modules
    importlib.reload(qrs)      

    if len(string_prefix) == len('You have selected: '):
        return 'Select a date to see it displayed here'
    else:
        return string_prefix
    


#     data_lists = ast.literal_eval(data_str)
#     default_fig = go.Figure()
#     if len(data_lists) > 2 :
#         path_fig = graph_path.graph_path(data_lists[0][value], data_lists[1][value], data_lists[2][value])
#         return 'You are currently seeing visitor "{}"'.format(value), path_fig
#     elif len(data_lists) == 0:
#         return "No Data found!", default_fig

#     return 'Slider is disabled', default_fig


if __name__ == '__main__':
    app.run_server(debug=True, host='0.0.0.0', port=8050)