# Use the official Python base image with the desired version
FROM python:3.9

# Set the working directory inside the container
WORKDIR /flask_dash_app

# Copy the requirements file to the working directory
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r /flask_dash_app/requirements.txt

# Copy the rest of the application code to the working directory
COPY . .

# Expose a port (if your application requires it)
EXPOSE 8050

# Define the command to run when the container starts
#CMD ["python3", "app.py"]
RUN chmod u+x ./entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]