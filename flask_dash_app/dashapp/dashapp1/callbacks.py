from dash.dependencies import Input, Output, State, ALL
from dash.exceptions import PreventUpdate
import plotly.graph_objs as go
from mysql.connector import pooling
import global_variables as gv
import queries as qrs
from plotting import plotters
import importlib
from contextlib import contextmanager
from dash import dcc, html, callback_context, no_update
import pandas as pd
from datetime import date, datetime, timedelta


# variables
current_month = date.today().month

# DB code

# DB connection config
db_connection_pool = None
# connection to db is implemented as a function called in app init at start of app creation
def init_db_pool():
    global db_connection_pool
    dbconfig = {
        "host": "mysql-db",
        "user": "regular_user",
        "port": "3306",
        "password": "regular_pass",
        "database": "futurium_exhibition_stats"
    }
    db_connection_pool = pooling.MySQLConnectionPool(
        pool_name="db_pool_dash_app",
        pool_size=10,
        pool_reset_session=True,
        **dbconfig
    )


@contextmanager
def get_db_connection():
    connection = db_connection_pool.get_connection()
    try:
        yield connection
    finally:
        connection.close()


@contextmanager
def get_db_cursor(connection):
    cursor = connection.cursor(buffered=True)
    try:
        yield cursor
    finally:
        cursor.close()


# to update max date allowed for queries in global vars, called within a callback
def update_yesterdays_date():
    today = datetime.now()
    yesterday = today - timedelta(days=1)
    return yesterday.date().strftime('%Y-%m-%d')

def register_callbacks(dashapp):

    # functions gets the right query text when user selects the corresponding graph type from the dropdown
    def fetch_data_from_db(query):
        #print(gv.start_date_string, gv.end_date_string)
        with get_db_connection() as connection:
            with get_db_cursor(connection) as cursor:
                cursor.execute("SET @startDate := %(start_date)s;", {'start_date': gv.start_date_string})
                cursor.execute("SET @endDate := %(end_date)s;", {'end_date': update_yesterdays_date()})
            
                cursor.execute(query)
    
                data = cursor.fetchall()
                
        return data



    @dashapp.callback(
        [
        Output('loading-spinner', 'children'),
        Output('query-msg-p', 'children'),
        Output('query-msg-p', 'style')
        ],
        
        [
        Input('submit-dates', 'n_clicks'),
        Input('dropdown', 'value')
        ]
    )
    def update_graph(n_clicks, graph_name): 

        # get the context fo the callback to determine what triggered it
        context = callback_context

        # get the id of the input component that triggered the callback
        input_id = context.triggered[0]['prop_id'].split('.')[0]

        # render empty graph if user changes the dropdown value to signal new graph creation
        if (input_id == 'dropdown' \
            or n_clicks == 0) \
            and \
            (not graph_name == gv.graph_types[8] \
            and not graph_name == gv.graph_types[9])  :
            
            # show an empty figure
            fig = go.Figure()
            # notify user for unsuccesfull data query
            msg = 'Selektiere eine Zeitraum und drucke Submit!'
            msg_style={'color': 'orange', 
                    'font-weight': 'bold', 
                        'justify-content': 'center'}
            graph= dcc.Graph(figure=fig, id='graph-content', style={"height": "600px", "width": "100%"})

            return graph, msg, msg_style

        # for path graphs warn user of extensive loading times if long time periods are selected
        elif input_id == 'dropdown' and \
            (graph_name == gv.graph_types[8] \
            or graph_name == gv.graph_types[9]):
            return dcc.Markdown(('''
                                **Bitte selektiere ein Zeitfenstern und drucke "Submit"!**
                                 
                                _Denk daran dass je **großer** der Zeitfenster desto **länger** wird diese Anfrage dauern!_
                                
                                 _Wenn du z.B. den wahrscheinlichsten Pfad anhand der gesamte Datenlage berechnen willst_
                                 _musst mit ca. 2 Stunden Zeit rechnen!_
                            '''), id='paths-msg'), no_update, no_update
        
        # this only executes if the user has used the submit button and updates the graphs
        else:
            # get the index of the selected graph type
            sel_graph_index = gv.graph_types.index(graph_name)
            #print(sel_graph_index)
            # get the query with the same list index as the selected graph type
            selected_query = qrs.queries[sel_graph_index]
            #print(selected_query)
            # fetch the right data only 
            data = fetch_data_from_db(selected_query)
            #print("Data: ")
            #print(data)
            pie_figs=[]
            
            # for double graphs
            if data and (sel_graph_index == 0 or sel_graph_index == 1):
                figures = plotters[sel_graph_index](data)
                # plot the data using the right 'plotter' function
                fig = figures[0]
                pie_figs = figures[1:]
                # notify user for sucessfull data query
                msg = 'Datenabfrage war erfolgreich!'
                msg_style={'color': 'green', 
                        'font-weight': 'bold',
                            'justify-content': 'center'}

            # single graphs
            elif data:
                # plot the data using the right 'plotter' function
                fig = plotters[sel_graph_index](data)
                # notify user for sucessfull data query
                msg = 'Datenabfrage war erfolgreich!'
                msg_style={'color': 'green', 
                        'font-weight': 'bold',
                            'justify-content': 'center'}

            
            # no data found case
            else:
                # show an empty figure
                fig = go.Figure()
                # notify user for unsuccesfull data query
                msg = 'Kein Daten für selektierte Zeitraum!'
                msg_style={'color': 'rgba(255, 0, 0, 0.5)', 
                        'font-weight': 'bold', 
                            'justify-content': 'center'}
                # graph_msg = ''

            if len(pie_figs) != 0:
                graph= [html.Div(dcc.Graph(figure=fig, id='graph-content', style={"height": "100%", "width": "100%"})),
                        dcc.Tabs(id='nav-tab', value='tab-1', children=[
                            dcc.Tab(label='Mensch', value='tab-1', 
                                    children=dcc.Graph(figure=pie_figs[0], id='graph-content1', style={"height": "600px", "width": "100%"})),
                            dcc.Tab(label='Technik', value='tab-2', 
                                    children=dcc.Graph(figure=pie_figs[1], id='graph-content2', style={"height": "600px", "width": "100%"})),    
                            dcc.Tab(label='Natur', value='tab-3', 
                                    children=dcc.Graph(figure=pie_figs[2], id='graph-content3', style={"height": "600px", "width": "100%"})),
                            dcc.Tab(label='Interaktiv', value='tab-4', 
                                    children=dcc.Graph(figure=pie_figs[3], id='graph-content4', style={"height": "600px", "width": "100%"})),
                        ])
                        ]
            
            elif sel_graph_index == 8 :
                graph= dcc.Graph(figure=fig, id='graph-content', style={"height": "1000px", "width": "100%"})
            elif sel_graph_index == 9 : # for random visitor paths with slider
                graph= [
                    dcc.Slider(min=0, max=10, step=1, value=0, id={"type": "dynamic-slider", "index": 'random-paths-slider'}),
                    dcc.Graph(figure=fig, id={"type": "dynamic-graph", "index":'random-paths-graph'}, style={"height": "1000px", "width": "100%"})
                    ]
            else:
                graph= dcc.Graph(figure=fig, id='graph-content', style={"height": "600px", "width": "100%"})

            return graph, msg, msg_style





    @dashapp.callback(
        
        Output('output-container-date-picker-range', 'children')
        ,
        [Input('my-date-picker-range', 'start_date'),
        Input('my-date-picker-range', 'end_date'),
        Input('submit-dates', 'n_clicks')
        ]
    )
    def update_output_date_picker(start_date, end_date, n_clicks):

        string_prefix = 'You have selected: '
        
        
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
        valid_daterange = toggle_btn_activation_for_valid_daterange(gv.start_date_string, gv.end_date_string)  
        


        if len(string_prefix) == len('You have selected: '):
            if start_date is None and end_date is None:
                return 'Selektiere ein Zeitraum für ein gezielte Datenabfrage!'
            elif valid_daterange:
                return string_prefix
            else:
                return 'Anfangsdatum kann nicht größer als Enddatum sein!!!'
        else:
            return string_prefix
    
    def toggle_btn_activation_for_valid_daterange(start_date, end_date):
        btn_style = {'color': 'grey', 'background_color': 'grey'}
        btn_disbl = False
        if date.fromisoformat(gv.start_date_string) > date.fromisoformat(gv.end_date_string) :
            return False
        else: return True


    def fetch_token_stations(query):
        with get_db_connection() as connection:
            with get_db_cursor(connection) as cursor:
                cursor.execute(query)
                data = cursor.fetchall()

        return data

    @dashapp.callback(
        [Output('table-station-editing', 'data'),
        Output('table-station-editing', 'dropdown')],
        Input('edit-stations-tab', 'n_clicks')
    )
    def edit_token_stations(n_clicks):
        # fetch data
        data = fetch_token_stations(qrs.token_stations_table)
        # turn to dataframe
        df = pd.DataFrame(data)
        # drop the first column with the db ids of the stations
        #df = df.drop(df.columns[0], axis=1)
        # name columns for the app
        df.columns = ["DB ID", "Station ID", "Station Name", "Installation Date", "Denkraum", "Station Typ", "Archiviert", "X Koordinate", "Y Koordinate", "Corona Offset"]
        # unique values from the Denkraum column of the df.
        unique_denkraum_values = df['Denkraum'].unique()
        # unique station type values
        unique_station_typ_values = df['Station Typ'].unique()
        # construct the dropdown options dynamically based on this list
        denkraum_options = [{'label': val, 'value': val} for val in unique_denkraum_values]
        # construct dropdown option dynamically 
        station_typ_options = [{'label': val, 'value': val} for val in unique_station_typ_values]

        # columns = [{'name': col, 'id': col, 'editable': (col in ['DB ID',
        #                                                         'Station Name', 
        #                                                          'Denkraum', 
        #                                                          'Station Typ', 
        #                                                          'X Koordinate', 
        #                                                          "Y Koordinate", 
        #                                                          "Corona Offset"]
                    #)} 
                    # if col not in ['Denkraum', 'Station Typ'] 
                    # else {'name': col, 'id': col, 'editable': True, 'presentation': 'dropdown', 'type': 'text'}
                    # for col in df.columns]
        
        

        dropdown_data = {
                        'Denkraum': {
                            'options': denkraum_options
                        },
                        'Station Typ': {
                            'options': station_typ_options
                        }
                    }

        return df.to_dict('records'), dropdown_data
        #print(df)


    @dashapp.callback(
    Output('feedback-p', 'children'),
    Output('table-station-editing', 'style_data_conditional'),
    #Input('table-button', 'n_clicks'),
    Input('table-station-editing', 'data'),
    State('table-station-editing', 'style_data_conditional')
    )
    def update_stations_table(table_data, style_data_conditional):
        # if not n_clicks:
        #     raise PreventUpdate

        errors = []
        #style_data_conditional = []
        #print(enumerate(table_data))
        for idx, row in enumerate(table_data):
            # Check each row's data
            # Check for Station Name
            station_name = row.get('Station Name')
            #print(station_name)
            if station_name and len(station_name) > 50:
                errors.append(f"Station Name in row {idx + 1} exceeds 50 characters.")
                style_data_conditional.append({
                    'if': {'row_index': idx, 'column_id': 'Station Name'},
                    'backgroundColor': 'rgba(255, 0, 0, 0.5)'
                })
            
            # Check for X Koordinate
            x_coord = row.get('X Koordinate')
            if x_coord:
                try:
                    float(x_coord)
                except ValueError:
                    errors.append(f"X Koordinate in row {idx + 1} is not a valid float.")
                    style_data_conditional.append({
                        'if': {'row_index': idx, 'column_id': 'X Koordinate'},
                        'backgroundColor': 'rgba(255, 0, 0, 0.5)'
                    })

            # Check for Y Koordinate
            y_coord = row.get('Y Koordinate')
            if y_coord:
                try:
                    float(y_coord)
                except ValueError:
                    errors.append(f"Y Koordinate in row {idx + 1} is not a valid float.")
                    style_data_conditional.append({
                        'if': {'row_index': idx, 'column_id': 'Y Koordinate'},
                        'backgroundColor': 'rgba(255, 0, 0, 0.5)'
                    })
            
            # Check for Corona Offset
            corona_offset = row.get('Corona Offset')
            if corona_offset:
                try:
                    int(corona_offset)
                except ValueError:
                    errors.append(f"Corona Offset in row {idx + 1} is not an integer.")
                    style_data_conditional.append({
                        'if': {'row_index': idx, 'column_id': 'Corona Offset'},
                        'backgroundColor': 'rgba(255, 0, 0, 0.5)'
                    })

        #print(errors)

        if errors:
            combined_list = []
            for error in errors:
                combined_list.extend([html.Div(error), html.Br()])
            return combined_list, style_data_conditional
        else:
            # This is where you'd typically update your database
            with get_db_connection() as conn:
                with get_db_cursor(conn) as cursor:
                    
                    for row in table_data:
                        sql_update_query = """
                        UPDATE token_stations 
                        SET 
                            `name_text` = %s,
                            `theme_area` = %s,
                            `tk_type` = %s,
                            `x_coord` = %s, 
                            `y_coord` = %s, 
                            `month_offset` = %s
                        WHERE token_db_id = %s
                        """
                        cursor.execute(sql_update_query, (row['Station Name'],
                                                            row['Denkraum'], 
                                                            row['Station Typ'],
                                                            row['X Koordinate'], 
                                                            row['Y Koordinate'], 
                                                            row['Corona Offset'],
                                                            row['DB ID']))  # assuming 'id' exists in each row
                conn.commit()
            #print(style_data_conditional)
            return "Data updated successfully!", gv.style_data_conditional # if all goes well return original styles
        
    
    @dashapp.callback(
        Output('download-dataframe-csv', 'data'),
        Input('download-btn', 'n_clicks'),
        State('dropdown', 'value'),
        prevent_initial_call=True
    )
    def downloaf_csv(n_clicks, graph_name):
        if gv.csv_file_data.empty:
            raise PreventUpdate
        else:
            filename = str(date.today()) + '_Data_von_' + gv.start_date_string + '_bis_' + \
                    gv.end_date_string + '_' + graph_name + ".csv"
            return dcc.send_data_frame(gv.csv_file_data.to_csv, filename )

    @dashapp.callback(
        Output({'type': 'dynamic-graph', 'index': 'random-paths-graph'}, 'figure'),
        [Input({'type': 'dynamic-slider', 'index': 'random-paths-slider'}, 'value'),
        State({'type': 'dynamic-graph', 'index': 'random-paths-graph'}, 'figure')]
    )
    def update_random_path_graph(slider_value, fig):

        # Function to interpolate points along the line
        def interpolate_points(x1, y1, x2, y2, num_arrows=3):
            return [(x1 + i*(x2-x1)/num_arrows, y1 + i*(y2-y1)/num_arrows) for i in range(1, num_arrows)]



        data_df = gv.csv_file_data
        coordinates = gv.coord_dict

        # Create a list of unique (band_code, date) tuples
        unique_combinations = pd.unique(list(zip(data_df['code'], data_df['date'])))

        current_armband_code = unique_combinations[slider_value][0]
        current_paths_date = unique_combinations[slider_value][1]

        # Iterate through each unique armband code
        current_path = data_df[(data_df['code'] == current_armband_code) & (data_df['date'] == current_paths_date)]


        print("Slider value:", slider_value)
        print("Current band:", current_armband_code )
        print("current path", current_path)
        # Check if fig is not None
        if fig is not None:
            # Convert fig to a plotly Figure if it's a dictionary
            if isinstance(fig, dict):
                fig = go.Figure(fig)

            # # Add trace
            # fig.add_trace(go.Scatter(x=[333], y=[244],
            #                         mode='markers',
            #                         marker=dict(size=10),
            #                         name='test'))

            # Draw lines for the selected slider path
            for i in range(len(current_path)-1):
                
                
                x1 = current_path.loc[i,'x_coord']
                y1 = current_path.loc[i,'y_coord']
                from_station = current_path.loc[i,'name']

                x2 = current_path.loc[i+1,'x_coord']
                y2 = current_path.loc[i+1,'y_coord']
                to_station = current_path.loc[i+1,'name']


                # Add points for the stations
                fig.add_trace(go.Scatter(x=[coordinates[from_station][0]], y=[coordinates[from_station][1]],
                                        mode='markers',
                                        marker=dict(size=10),
                                        name=from_station
                                        ))

                # Add an arrow annotation at the endpoint of the line
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
            # fig.add_trace(go.Scatter(x=[coord_dict[path[-1]][0]], y=[coord_dict[path[-1]][1]],
            #                         mode='markers',
            #                         marker=dict(size=10),
            #                         name=path[-1]
            #                         ))
            
            fig.update(layout_title_text=gv.random_paths_msg,
                   layout_showlegend=True)
        return fig