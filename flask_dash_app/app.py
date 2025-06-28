"""
Main Flask application entry point.
Initializes the Flask app and registers the Dash app.
"""
from flask import Flask, render_template
import os
import config
from utils import db

# Set up logging
logger = config.setup_logging("flask_dash_app")

# Initialize the Flask application
app = Flask(
    __name__.split('.')[0], 
    template_folder='/flask_dash_app/dashapp/templates'
)

# Initialize the database connection pool
db.init_db_pool("db_pool_flask_dash_app", 10)

# Register the Dash app with the main Flask application
with app.app_context():
    from dashapp import init_dash
    app = init_dash(app)

@app.route('/dashboard/')
def index():
    """
    Render the dashboard index page.
    
    Returns:
        str: Rendered HTML template
    """
    return render_template("base.html", title='Futurium Exhibition Statistics')

if __name__ == "__main__":
    # Get port from environment or use default
    port = int(os.environ.get("FLASK_PORT", 8050))
    
    logger.info(f"Starting Flask application on port {port}")
    app.run(host='0.0.0.0', port=port, debug=True)
