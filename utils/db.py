"""
Database utility functions for the application.
Provides a centralized way to manage database connections.
"""
from mysql.connector import pooling
from contextlib import contextmanager
import config

# Global connection pool
db_connection_pool = None

def init_db_pool(pool_name="db_pool", pool_size=5):
    """
    Initialize the database connection pool.
    
    Args:
        pool_name (str): Name of the connection pool
        pool_size (int): Size of the connection pool
        
    Returns:
        mysql.connector.pooling.MySQLConnectionPool: Database connection pool
    """
    global db_connection_pool
    
    if db_connection_pool is None:
        db_connection_pool = pooling.MySQLConnectionPool(
            pool_name=pool_name,
            pool_size=pool_size,
            pool_reset_session=True,
            **config.DB_CONFIG
        )
    
    return db_connection_pool

@contextmanager
def get_db_connection():
    """
    Get a database connection from the pool.
    
    Yields:
        mysql.connector.connection.MySQLConnection: Database connection
    """
    # Ensure pool is initialized
    if db_connection_pool is None:
        init_db_pool()
    
    # Get connection from pool
    connection = db_connection_pool.get_connection()
    
    try:
        yield connection
    finally:
        connection.close()

@contextmanager
def get_db_cursor(connection, buffered=True):
    """
    Get a cursor from a database connection.
    
    Args:
        connection (mysql.connector.connection.MySQLConnection): Database connection
        buffered (bool): Whether to use a buffered cursor
        
    Yields:
        mysql.connector.cursor.MySQLCursor: Database cursor
    """
    cursor = connection.cursor(buffered=buffered)
    
    try:
        yield cursor
    finally:
        cursor.close()

def execute_query(query, params=None, fetch=True):
    """
    Execute a database query.
    
    Args:
        query (str): SQL query to execute
        params (dict, optional): Parameters for the query
        fetch (bool): Whether to fetch results
        
    Returns:
        list: Query results if fetch is True, otherwise None
    """
    with get_db_connection() as connection:
        with get_db_cursor(connection) as cursor:
            cursor.execute(query, params or {})
            
            if fetch:
                return cursor.fetchall()
            else:
                connection.commit()
                return None

def execute_query_with_date_range(query, start_date=None, end_date=None, params=None, fetch=True):
    """
    Execute a database query with date range parameters.
    
    Args:
        query (str): SQL query to execute
        start_date (str, optional): Start date in YYYY-MM-DD format
        end_date (str, optional): End date in YYYY-MM-DD format
        params (dict, optional): Additional parameters for the query
        fetch (bool): Whether to fetch results
        
    Returns:
        list: Query results if fetch is True, otherwise None
    """
    with get_db_connection() as connection:
        with get_db_cursor(connection) as cursor:
            # Set date range parameters
            cursor.execute("SET @startDate := %(start_date)s;", 
                          {'start_date': start_date or config.STATS_DATE_RANGES["start_date"]})
            cursor.execute("SET @endDate := %(end_date)s;", 
                          {'end_date': end_date or config.STATS_DATE_RANGES["end_date"]})
            
            # Execute the main query
            cursor.execute(query, params or {})
            
            if fetch:
                return cursor.fetchall()
            else:
                connection.commit()
                return None