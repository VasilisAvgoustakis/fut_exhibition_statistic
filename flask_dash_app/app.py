from flask import Flask
from flask import render_template
# implements a WSGI application and acts as the central object.
# passed the name of the module or package of the application.
# act as a central registry for the view functions, the URL rules, template configuration.
app = Flask(__name__.split('.')[0], template_folder='/flask_dash_app/dashapp/templates') # split refering to flask_dash_app/app.py 

# Register the Dash app with the main Flask application in falsk_dash_app/app.py.
with app.app_context():
    from dashapp import init_dash
    app = init_dash(app)


@app.route('/dashboard/')
def index():
    return render_template("base.html", title='Home Page')


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8050)
