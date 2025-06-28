"""
MQTT utility functions for the application.
Provides a centralized way to manage MQTT connections.
"""
import paho.mqtt.subscribe as sub
import config

def subscribe_to_topic(callback, topic=None, hostname=None):
    """
    Subscribe to an MQTT topic.
    
    Args:
        callback (callable): Callback function to handle messages
        topic (str, optional): MQTT topic to subscribe to
        hostname (str, optional): MQTT broker hostname
        
    Returns:
        None
    """
    sub.callback(
        callback,
        topic or config.MQTT_CONFIG["topic"],
        hostname=hostname or config.MQTT_CONFIG["broker_address"]
    )