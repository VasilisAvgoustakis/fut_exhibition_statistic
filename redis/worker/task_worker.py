import redis
import mysql.connector
from mysql.connector import pooling
import json
import time

# Initialize Redis connection
# Set up Redis connection
redis_host = "redis"  # Use the Docker service name as hostname
redis_port = 6379
redis_db = redis.Redis(host=redis_host, port=redis_port, db=0, decode_responses=True)


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


def execute_query_from_redis():
    while True:
        # Blocking pop from Redis queue
        _, task_data = redis_db.blpop('query_queue')
        print(task_data)
        # Convert task data back from JSON string
        task = json.loads(task_data)
        # Get DB connection and cursor
        connection = db_connection_pool.get_connection()
        cursor = connection.cursor(buffered=True)
        try:
            cursor.execute("SET @startDate := %s;", (task['start_date'],))
            cursor.execute("SET @endDate := %s;", (task['end_date'],))
            # Execute the query
            cursor.execute(task['query'])
            results = cursor.fetchall()
            # Here, you could convert results to a JSON string and store them back in Redis
            # associated with the task ID for the Dash app to retrieve
            redis_db.set(f"result:{task['id']}", json.dumps(results))
        except Exception as e:
            print(f"Error executing query {task['query']}: {str(e)}")
        finally:
            cursor.close()
            connection.close()
        time.sleep(1)  # Prevents tight loop if no data is in the queue

if __name__ == "__main__":
    print("WORKERRRR")
    init_db_pool()
    execute_query_from_redis()
