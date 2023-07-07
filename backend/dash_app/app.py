
import datetime
from datetime import date
import dash
#import dash_core_components as dcc
from dash import dcc
#import dash_html_components as html
from dash import html
from dash.dependencies import Input, Output
from read_path_coordinates import get_path_coordinates
import graph_path
import plotly.graph_objs as go
import ast


yesterday = date.today() - datetime.timedelta(days=1)
current_month = date.today().month

external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

app = dash.Dash(__name__, external_stylesheets=external_stylesheets)

server = app.server

# List containing tha categories of graphs that can be displayed by the app
graph_types = ['Average Scans per Station/Month Bar', 'Average Scans per Station/Month Pie',
               'Visitors per day', 'Questions', "Avg Time/Region",
               "Region popularity", "Total Scans per Region", "Total Scans per Station Bar",
               "Total Scans per Station Pie", "Visitor Paths"]

app.layout = html.Div([
    html.H2('Futurium-Exhibition-Statistics'),
    dcc.Dropdown(
        id='dropdown',
        options=[{'label': i, 'value': i} for i in graph_types],
        value='Average Scans per Station/Month Bar'
    ),
    dcc.DatePickerRange(
                id='my-date-picker-range',
                min_date_allowed=date(2020, 9, 23),
                max_date_allowed=yesterday,
                initial_visible_month=date.today(),

                display_format="DD.MM.YYYY",
                updatemode='bothdates'
                ),

    html.Div(id='output-container-date-picker-range'),
    dcc.Slider(
        id='slider',
        min=0,
        step=1,
        value=0,
        updatemode='mouseup'
    ),
    html.Div(id='slider-output-container'),
    html.Button('submit', id='submit-dates', n_clicks=0 ),
    # I frame for all graph types except
    html.Iframe(id='selected-graph-type',
                style={"height": "900px", "width": "100%"}, hidden=True),
    html.Div(dcc.Graph(id='paths-graph', style={"height": "200%", "width": "100%"}),
             id='graph-div', hidden=True, style={"height": "200%","width": "100%"})


])

@app.callback(
    Output('selected-graph-type', 'src'),
    Output('selected-graph-type', 'hidden'),
    Output('my-date-picker-range', 'disabled'),
    Output('graph-div', 'hidden'),
    Output('slider', 'disabled'),
    Input('dropdown', 'value')

)
def select_graph_type(value):

    graphs_path = r"C:\Users\Vasilis Avgoustakis\Desktop\Futurium_Exhibition_Statistics-1.3\html"

    if value == 'Visitors per day':
        url = "http://172.25.11.96/exhibition_visitors_per_day.html"
        #path = "/var/www/html/exhibition_visitors_per_day.html"
        return url, False, True, True, True

    if value == 'Average Scans per Station/Month Bar':
        url = "http://172.25.11.96/average_tokenScans_perStation_perMonth_bar.html"
        path = "/var/www/html/average_tokenScans_perStation_perMonth_bar.html"
        return url, False, True, True, True

    if value == 'Average Scans per Station/Month Pie':
        url = "http://172.25.11.96/average_tokenScans_perStation_perMonth_pie.html"
        path = "/var/www/html/average_tokenScans_perStation_perMonth_pie.html"
        return url, False, True, True, True

    if value == 'Questions':
        url = "http://172.25.11.96/questionsBar_Scans.html"
        path = "/var/www/html/questionsBar_Scans.html"
        return url, False, True, True, True

    if value == 'Avg Time/Region':
        url = "http://172.25.11.96/Region_Average_TimesperArmband.html"
        path = "/var/www/html/Region_Average_TimesperArmband.html"
        return url, False, True, True, True

    if value == 'Region popularity':
        url = "http://172.25.11.96/token_popularity_per_region.html"
        path = "/var/www/html/token_popularity_per_region.html"
        return url, False, True, True, True

    if value == 'Total Scans per Region':
        url = "http://172.25.11.96/token_scans_per_region.html"
        path = "/var/www/html/token_scans_per_region.html"
        return url, False, True, True, True

    if value == 'Total Scans per Station Bar':
        url = "http://172.25.11.96/total_tokenScans_perStation_bar.html"
        path = "/var/www/html/total_tokenScans_perStation_bar.html"
        return url, False, True, True, True

    if value == 'Total Scans per Station Pie':
        url = "http://172.25.11.96/total_tokenScans_perStation_pie.html"
        path = "/var/www/html/total_tokenScans_perStation_pie.html"
        return url, False, True, True, True

    if value == 'Visitor Paths':
        url = "http://172.25.11.96/exhibition_paths.html"
        path = "/var/www/html/exhibition_paths.html"
        return None, True, False, False, False


@app.callback(
    Output('output-container-date-picker-range', 'children'),
    [Input('my-date-picker-range', 'start_date'),
     Input('my-date-picker-range', 'end_date')]
)
def update_output_date_picker(start_date="2020-09-23", end_date="2020-12-23"):

    string_prefix = 'You have selected: '
    #print(start_date)
    if start_date is not None:
        start_date_object = date.fromisoformat(start_date)
        start_date_string = start_date_object.strftime('%B %d, %Y')
        string_prefix = string_prefix + 'Start Date: ' + start_date_string + ' | '
    if end_date is not None:
        end_date_object = date.fromisoformat(end_date)
        end_date_string = end_date_object.strftime('%B %d, %Y')
        string_prefix = string_prefix + 'End Date: ' + end_date_string

    if len(string_prefix) == len('You have selected: '):
        return 'Select a date to see it displayed here'
    else:
        return string_prefix


@app.callback(
    [Output('submit-dates', 'disabled'),
     Output('submit-dates', 'data-*')],
    [Input('submit-dates', 'n_clicks'),
     Input('my-date-picker-range', 'start_date'),
     Input('my-date-picker-range', 'end_date'),
     ]
)
def submit_dates( clicks, start_date="2020-09-23", end_date="2020-12-23",):
    # only enable button start and end date are set
    disable = True
    graph_data = tuple()
    if start_date is not None and end_date is not None:
        disable = False
    changed_id = [p['prop_id'] for p in dash.callback_context.triggered][0]
    if 'submit-dates' in changed_id and start_date is not None:
        msg = 'Button was clicked'
        graph_data = get_path_coordinates(start_date, end_date)
    else:
        msg = 'None of the buttons have been clicked yet'
    return disable, str(graph_data)


@app.callback(
    [Output('slider-output-container', 'children'),
     Output('paths-graph', 'figure')],
    [Input('slider', 'value'),
     Input('submit-dates','data-*')]
)
def update_path(value, data_str):
    data_lists = ast.literal_eval(data_str)
    default_fig = go.Figure()
    if len(data_lists) > 2 :
        path_fig = graph_path.graph_path(data_lists[0][value], data_lists[1][value], data_lists[2][value])
        return 'You are currently seeing visitor "{}"'.format(value), path_fig
    elif len(data_lists) == 0:
        return "No Data found!", default_fig

    return 'Slider is disabled', default_fig


if __name__ == '__main__':
    app.run_server(debug=True, host='172.25.11.96')