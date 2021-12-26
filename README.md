# Airflow service caller
We need to create a GCP Pub/Sub topic.
The DAG also needs a couple of variables defined to it:

* GCP_TOPIC - The name of the topic that we will subscribe to which will be published by the service app.
* GCP_PROJECTID - The project id that will hold the subscription.

Define a Composer connection called `rest_serve` that points to the REST service.


We need to enable some GCP services:

* PubSub
* Composer

We need to run the Service app called `app.py`.  This requires Flask to be installed.  We suggest
running this on a Compute Engine.

1. Create a GCP Topic
2. Create a Composer instance
3. Install the DAG in composer
4. Start the Python APP on the machine hosting the service
5. Set the variables in Composer (GCP_TOPIC & GCP_PROJECTID)
6. Set the connection (rest_serve)
7. Run the dag

The important files in this project are:

* app.py
* cloudbuild.yaml
* Dockerfile
* Makefile
* requirements.txt
* policies/*
* airflow_service_caller.py

To build our solution:

```
$ make setup
$ make app-setup
```