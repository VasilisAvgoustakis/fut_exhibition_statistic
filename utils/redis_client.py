"""
Redis utility functions for the application.
Provides a centralized way to manage Redis connections.
"""
import redis
import json
import uuid
import config

# Global Redis client
redis_client = None

def get_redis_client():
    """
    Get a Redis client.
    
    Returns:
        redis.Redis: Redis client
    """
    global redis_client
    
    if redis_client is None:
        redis_client = redis.Redis(
            host=config.REDIS_CONFIG["host"],
            port=config.REDIS_CONFIG["port"],
            db=config.REDIS_CONFIG["db"],
            decode_responses=True
        )
    
    return redis_client

def test_redis_connection():
    """
    Test the Redis connection.
    
    Returns:
        bool: True if the connection is successful, False otherwise
    """
    try:
        client = get_redis_client()
        return client.ping()
    except Exception as e:
        print(f"Failed to connect to Redis: {e}")
        return False

def enqueue_query(query, start_date=None, end_date=None):
    """
    Enqueue a database query for asynchronous execution.
    
    Args:
        query (str): SQL query to execute
        start_date (str, optional): Start date in YYYY-MM-DD format
        end_date (str, optional): End date in YYYY-MM-DD format
        
    Returns:
        str: Task ID
    """
    # Generate a unique identifier for this task
    task_id = f"query-{uuid.uuid4()}"
    
    # Package the query and its ID into a dictionary
    task = {
        'id': task_id,
        'query': query,
        'status': 'queued',
        'start_date': start_date or config.STATS_DATE_RANGES["start_date"],
        'end_date': end_date or config.STATS_DATE_RANGES["end_date"]
    }
    
    # Convert the task dictionary to a JSON string
    task_json = json.dumps(task)
    
    # Push the task to the Redis list (queue)
    get_redis_client().rpush('query_queue', task_json)
    
    return task_id

def get_query_result(task_id, timeout=20):
    """
    Get the result of an asynchronous query.
    
    Args:
        task_id (str): Task ID
        timeout (int): Timeout in seconds
        
    Returns:
        dict: Query result or None if not available
    """
    client = get_redis_client()
    
    if client.exists(f"result:{task_id}"):
        result_json = client.get(f"result:{task_id}")
        return json.loads(result_json)
    
    return None