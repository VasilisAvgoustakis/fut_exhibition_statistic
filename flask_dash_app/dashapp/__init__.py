import dash
from flask import Flask
from dashapp.dashapp1.layout import layout as dash_layout
from .dashapp1.callbacks import register_callbacks
from .dashapp1.callbacks import init_db_pool


external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']


def init_dash(flask_app):
    # create dash app object and pass flask sever at its server parameter
    dash_app = dash.Dash(server=flask_app, 
                         name='Ausstellungs Stats', 
                         url_base_pathname="/dashboard/",
                         external_stylesheets=external_stylesheets,
                         title='Ausstellung Statistik'
                         #requests_pathname_prefix='/dashboard/'  # This is crucial. It tells Dash to serve component dependencies from this path.
                         )
    
    # add layout to app
    dash_app.layout = dash_layout
    # initiate connection pool to db
    init_db_pool()
    # register callbacks to dash app
    register_callbacks(dash_app)

    # return the flask server associated with the app
    return dash_app.server


if __name__ == '__main__':
    app = dash.Dash("Ausstellung Statistik")
    app.run_server(debug=True)