# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Make port 80 available to the world outside this container
# This line is optional and depends on your application needs
EXPOSE 80

# Define environment variable
# This line is optional and can be customized based on your needs
ENV NAME Worker

# Run worker.py when the container launches
# Replace 'worker.py' with the path to your script
CMD ["python", "./task_worker.py"]
