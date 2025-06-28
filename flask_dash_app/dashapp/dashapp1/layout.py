"""
Layout definition for the Dash application.
"""
from dash import dash_table, dcc, html
from datetime import date, datetime, timedelta
import config
import urllib
import importlib
from .callbacks import update_yesterdays_date

def serve_layout():
    """
    Create and return the layout for the Dash application.
    
    Returns:
        dash.html.Div: Layout for the Dash application
    """
    layout = html.Div([
        html.H2('Futurium Ausstellung Statistik'),
        dcc.Tabs(id='main-nav-tab', value='tab-1', children=[
            dcc.Tab(id='stats-tab', label='Statistik', value='tab-1',
                    children=[
                    dcc.Dropdown(
                        id='dropdown',
                        options=[{'label': i, 'value': i} for i in config.GRAPH_TYPES],
                        value=config.GRAPH_TYPES[0]
                    ),
                    dcc.DatePickerRange(
                                id='my-date-picker-range',
                                min_date_allowed=config.STATS_DATE_RANGES["start_date"],
                                max_date_allowed=update_yesterdays_date(),
                                initial_visible_month=date.today(),
                                display_format="DD.MM.YYYY",
                                start_date_placeholder_text='23.09.2020',
                                end_date_placeholder_text=datetime.strptime(update_yesterdays_date(), '%Y-%m-%d').strftime('%d.%m.%Y'),
                                updatemode='singledate',
                                clearable=True,
                                ),
                    html.Div(id='output-container-date-picker-range'),
                    html.Button('Submit', id='submit-dates', n_clicks=0),
                    html.Button('CSV Herunterladen', id='download-btn', n_clicks=0, 
                               style={'position': 'absolute', 'right': '0'}),
                    dcc.Download(id="download-dataframe-csv"),
                    html.Div(
                        id='query-msg-div',
                        style={
                            "display": "flex",
                            "flexDirection": "column",
                            "alignItems": "center",
                            "justifyContent": "center"
                        },
                        children=[
                            # Include the CSS using the style tag
                            html.Link(rel='stylesheet', href='data:text/css,' + urllib.parse.quote("""
                                *[data-dash-is-loading="true"]{
                                    visibility: hidden;                                                              
                                }
                                *[data-dash-is-loading="true"]::after{
                                    content: "Daten werden geholt...bitte warten!";
                                    color: orange;
                                    font-weight: bold;
                                    text-align: center;                                                              
                                    visibility: visible;                                                               
                                }
                            """)), 
                            html.P(id='query-msg-p')
                        ]
                    ),
                    html.Div(
                        id='graph-cont',
                        children=[
                            dcc.Loading(
                                id='loading-spinner',
                                children=[],
                                type='circle',
                                style={'position': 'absolute', 'top': '0'}
                            )
                        ]
                    )
                ]),
                dcc.Tab(
                    label='Token Stations', 
                    value='tab-2',
                    id='edit-stations-tab',
                    children=[
                        html.Div(
                            id='token-stations-table',
                            children=[
                                # Empty Div to display feedback to the user
                                html.Div(
                                    id='feedback-div',
                                    children=html.P(id="feedback-p")
                                ),  
                                dash_table.DataTable(
                                    id='table-station-editing',
                                    editable=True,
                                    sort_action='native',
                                    columns=[
                                        {'name': 'DB ID', 'id': 'DB ID', 'editable': False},
                                        {'name': 'Station ID', 'id': 'Station ID', 'editable': False},
                                        {'name': 'Station Name', 'id': 'Station Name', 'editable': True, 'type': 'text', 
                                         'validation': {'allow_null': 'True', 'default': 'default'}, 
                                         'on_change': {'action': 'validate', 'failure': 'default'}},
                                        {'name': 'Denkraum', 'id': 'Denkraum', 'editable': True, 'presentation': 'dropdown'},
                                        {'name': 'Station Typ', 'id': 'Station Typ', 'editable': True, 'presentation': 'dropdown'},
                                        {'name': 'X Koordinate', 'id': 'X Koordinate', 'editable': True, 'type': 'numeric'},
                                        {'name': 'Y Koordinate', 'id': 'Y Koordinate', 'editable': True, 'type': 'numeric'},
                                        {'name': 'Corona Offset', 'id': 'Corona Offset', 'editable': True, 'type': 'numeric'} 
                                    ],
                                    style_header={
                                        'backgroundColor': 'black',
                                        'color': 'white',
                                        'fontWeight': 'bold'
                                    },
                                    style_data_conditional=config.TABLE_STYLE_DATA_CONDITIONAL
                                )
                            ]
                        ),
                    ]
                )
            ]
        )
    ])
    return layout