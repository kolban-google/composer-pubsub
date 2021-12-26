# Sample Flask application that exposes a sample REST service
#
# /serve?correlid=???
#

import flask as Flask
import threading
import time
import os
from google.cloud import pubsub_v1

app = Flask.Flask(__name__)

# Sample long running task that executes for an extended period of time.
def long_running_task(**kwargs):
    correlid = kwargs.get('correlid', {}) # Retrieve the correlid value from the passed in parameters.
    print("Starting long running background task")

    # Do some busy work for a period of time.
    for i in range(10):
        time.sleep(1)
        print(str(i+1) + " of 10")
    
    # The long running work has been completed, publish an event that the work has completed.
    publisherClient = pubsub_v1.PublisherClient()
    topic_name = publisherClient.topic_path(os.getenv('GOOGLE_CLOUD_PROJECT'), os.getenv('GCP_TOPIC'))
    future = publisherClient.publish(topic_name, b'Work Done!', correlid=correlid)
    future.result()
    # End of long_running_task

# Define the Flask endpoint:  POST /serve?correlid=<CORRELID>
@app.route("/serve", methods=['POST'])
def serveRequest():
    correlid = Flask.request.args.get('correlid')  # Get the requested Correlid
    print("The Correlid was " + correlid)
    data = Flask.request.data.decode('utf-8')

    # Start the background thread that runs the long running task
    thread = threading.Thread(target=long_running_task, kwargs={'correlid': correlid})
    thread.start()

    # Return the response to the REST request.
    return Flask.make_response("Hello {}".format(data), 200)
    # End of serveRequest

if __name__ == "__main__":
    print(f"Project: {os.getenv('GOOGLE_CLOUD_PROJECT')}, Topic: {os.getenv('GCP_TOPIC')}, Port: {os.getenv('PORT')}")
    app.run(host='0.0.0.0', port=int(os.environ.get("PORT", 5000)))
