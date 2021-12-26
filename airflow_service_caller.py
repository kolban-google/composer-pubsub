from datetime import timedelta, datetime
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.providers.google.cloud.operators.pubsub import PubSubDeleteSubscriptionOperator
from airflow.providers.google.cloud.sensors.pubsub import PubSubPullSensor
from airflow.providers.google.cloud.hooks.pubsub import PubSubHook
from google.cloud.pubsub_v1.types import Duration
from airflow.models import Variable
import uuid

# Airflow DAG to make a service call and then wait for a background task to complete.
# Design uses GCP PubSub.  High level algorithm is:
#
# 1. Create a subscription to a GCP topic that has a unique identity.
# 2. Make a REST service call to a long running service that returns immediately.
# 3. Wait / block until a PubSub response is received.
# 4. Cleanup by deleting the subscription.
#
# Solution expects a variable called GCP_PROJECT to identify the GCP project owning the subscription.
#

with DAG(
    'test',
    schedule_interval=None,
    start_date=datetime(2021, 12, 10),
    description="Service Caller DAG"
) as dag:

    def _createSubscription():
        subscriptionName = f"airflow-test-{str(uuid.uuid4())}"
        topic = Variable.get("GCP_TOPIC")
        hook = PubSubHook()
        result = hook.create_subscription(
            topic=topic,
            subscription=subscriptionName,
            expiration_policy={
                "ttl": Duration(seconds=24*60*60)
            },
            labels={
                "source": "dag"
            },
            filter_=f'attributes.correlid = "{subscriptionName}"'
        )
        return subscriptionName  # The return value is the subscription name


    create_subscription_task = PythonOperator(
        task_id='CreateSubscription',
        python_callable=_createSubscription
    )

    subscription = create_subscription_task.output

    # Invoke the back end REST Service
    rest_invoke_task = SimpleHttpOperator(
        task_id='InvokeREST',
        http_conn_id='rest_serve',
        method='POST', 
        endpoint="/serve?correlid={{task_instance.xcom_pull(task_ids='CreateSubscription', key='return_value')}}",
        headers={}
    )

    # We will use the GCP_PROJECT variable to obtain the GCP project associated with the subscription.
    pubsubpullsensor_task = PubSubPullSensor(
        task_id="WaitForCompletion",
        project_id="{{var.value.GCP_PROJECTID}}",
        subscription=subscription,
        max_messages=1
    )

    delete_subscription_task = PubSubDeleteSubscriptionOperator(
        task_id='DeleteSubscription',
        subscription=subscription
    )

    create_subscription_task >> rest_invoke_task >> pubsubpullsensor_task >> delete_subscription_task