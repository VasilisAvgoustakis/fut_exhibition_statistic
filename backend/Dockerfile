# Use the official Python base image with the desired version
FROM python:3.9

# Set the working directory inside the container
WORKDIR /backend

# Copy the requirements file to the working directory
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r /backend/requirements.txt

# Copy the rest of the application code to the working directory
COPY . .

# Expose a port (if your application requires it)
EXPOSE 8000

# Define the command to run when the container starts
CMD ["python3", "main.py"]
