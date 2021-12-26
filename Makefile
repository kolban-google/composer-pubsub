# Start of config
REGION=us-central1
PROJECT=kolban-delete11
COMPOSER_ENV=composer
SERV_IP=127.0.0.1
SERV_PORT=5000
TOPIC=mytopic

REPO_NAME=testrepo1
IMAGE=test1

COMPUTE_ENGINE_INSTANCE=flaskapp
SERVICE_ACCOUNT=composer-sa

# -- End config.  Do not edit the following variables.

REPO_URL=$(REGION)-docker.pkg.dev/$(PROJECT)/$(REPO_NAME)
IMAGE_NAME=$(REPO_URL)/$(IMAGE)
SERVICE_ACCOUNT_FULL=$(SERVICE_ACCOUNT)@$(PROJECT).iam.gserviceaccount.com
COMPOSER_VERSION=composer-1.17.7-airflow-2.1.4

#
# List all of the targets that we can build.
#
all:
	@echo "setup - Setup the environment for our sample"
	@echo "app-setup - Setup the Flask app to serve REST calls"
	@echo "clean - Clean the environment by deleting resources created in this sample"
	@echo "copy-dag - Copy the DAG to GCP Composer"
	@echo "setup-google-internal - Used by Google staff to setup on Googler sandboxes"

#
# Setup the services that are to be used by our sample.
#
setup: enable-services topic-create security-create composer-create composer-set-variables composer-set-connid copy-dag
	@echo "#"
	@echo "# All composer and pubsub setup done.  Consider \"make app-setup\" to setup the flask app."
	@echo "#"

#
# Setup the flask app.
#
app-setup: repository-create cloud-build compute-engine-create composer-set-connid-compute-engine
	gcloud compute firewall-rules create flaskapp --allow=tcp:$(PORT) --direction=INGRESS --project=$(PROJECT) --network=default --source-ranges=0.0.0.0/0
	@echo "App built"

app-clean: repository-delete compute-engine-delete
	@echo "App cleaned"


#
# Clean (remove) resources created in this sample.
#
clean: composer-delete topic-delete repository-delete compute-engine-delete
	@echo "#"
	@echo "# App - All cleaned.  Run \"make app-setup\" to create."
	@echo "#"

security-create:
	-gcloud iam service-accounts create $(SERVICE_ACCOUNT) --project=$(PROJECT)
	gcloud projects add-iam-policy-binding $(PROJECT) \
    	--member="serviceAccount:$(SERVICE_ACCOUNT)@$(PROJECT).iam.gserviceaccount.com" \
    	--role="roles/editor"
	gcloud projects add-iam-policy-binding $(PROJECT) \
    	--member="serviceAccount:$(shell gcloud projects describe $(PROJECT) --format="value(projectNumber)")-compute@developer.gserviceaccount.com" \
    	--role="roles/editor"
#
# The Googler default environment is restricted in its organization policies and the following need to be modified.
#
# compute.restrictVpcPeering
# compute.requireShieldedVm
# compute.requireOsLogin
# compute.vmCanIpForward
# compute.vmExternalIpAccess
setup-google-internal: project-policies
	@echo "#"
	@echo "# Creating the 'default' VPC network"
	@echo "#"
	gcloud services enable compute.googleapis.com --project=$(PROJECT)
	-gcloud compute networks create default --project=$(PROJECT)
	gcloud compute firewall-rules create internal --allow=all --direction=INGRESS --project=$(PROJECT) --network=default --source-ranges=10.128.0.0/9
	gcloud compute firewall-rules create allow-ssh --allow=tcp:22 --direction=INGRESS --project=$(PROJECT) --network=default --source-ranges=0.0.0.0/0
	@echo "# Next steps might be 'make setup'"

# Update the Google internal sandbox project changing the default organization policies for our project
# to be less restrictive.
project-policies:
	gcloud services enable orgpolicy.googleapis.com --project=$(PROJECT)
	sleep 30
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.requireOsLogin.yaml > policies/compute.requireOsLogin_final.yaml
	gcloud org-policies set-policy policies/compute.requireOsLogin_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.requireShieldedVm.yaml > policies/compute.requireShieldedVm_final.yaml
	gcloud org-policies set-policy policies/compute.requireShieldedVm_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.restrictVpcPeering.yaml > policies/compute.restrictVpcPeering_final.yaml
	gcloud org-policies set-policy policies/compute.restrictVpcPeering_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.vmCanIpForward.yaml > policies/compute.vmCanIpForward_final.yaml
	gcloud org-policies set-policy policies/compute.vmCanIpForward_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.vmExternalIpAccess.yaml > policies/compute.vmExternalIpAccess_final.yaml
	gcloud org-policies set-policy policies/compute.vmExternalIpAccess_final.yaml

	# Tests
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.trustedImageProjects.yaml > policies/compute.trustedImageProjects_final.yaml
	gcloud org-policies set-policy policies/compute.trustedImageProjects_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/iam.disableServiceAccountKeyCreation.yaml > policies/iam.disableServiceAccountKeyCreation_final.yaml
	gcloud org-policies set-policy policies/iam.disableServiceAccountKeyCreation_final.yaml

	# Tests
	sed 's/PROJECTID/$(PROJECT)/g' policies/iam.allowedPolicyMemberDomains.yaml > policies/iam.allowedPolicyMemberDomains_final.yaml
	gcloud org-policies set-policy policies/iam.allowedPolicyMemberDomains_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/storage.uniformBucketLevelAccess.yaml > policies/storage.uniformBucketLevelAccess_final.yaml
	gcloud org-policies set-policy policies/storage.uniformBucketLevelAccess_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/appengine.disableCodeDownload.yaml > policies/appengine.disableCodeDownload_final.yaml
	gcloud org-policies set-policy policies/appengine.disableCodeDownload_final.yaml

	# Tests
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.disableSerialPortAccess.yaml > policies/compute.disableSerialPortAccess_final.yaml
	gcloud org-policies set-policy policies/compute.disableSerialPortAccess_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/compute.disableSerialPortLogging.yaml > policies/compute.disableSerialPortLogging_final.yaml
	gcloud org-policies set-policy policies/compute.disableSerialPortLogging_final.yaml
	sed 's/PROJECTID/$(PROJECT)/g' policies/sql.restrictAuthorizedNetworks.yaml > policies/sql.restrictAuthorizedNetworks_final.yaml
	gcloud org-policies set-policy policies/sql.restrictAuthorizedNetworks_final.yaml

	rm policies/*final.yaml
#
# Copy the DAG to the GCP Composer bucket so that it is picked up for execution.
#
copy-dag:
	gsutil cp dags/airflow_service_caller.py $(shell gcloud composer environments describe $(COMPOSER_ENV) --project=$(PROJECT) --location=$(REGION) --format="value(config.dagGcsPrefix)")

#
# Create a GCP Composer environment.
#
composer-create:
	@echo "#"
	@echo "# Creating the composer environment."
	@echo "#"
	-gcloud composer environments create $(COMPOSER_ENV) \
		--location=$(REGION) \
		--python-version=3 \
		--service-account=$(SERVICE_ACCOUNT_FULL) \
		--image-version=$(COMPOSER_VERSION) \
		--project=$(PROJECT)

#
# Delete a GCP Composer environment.
#
composer-delete:
	-gcloud composer environments delete $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		--quiet

#
# Set variables within the GCP Composer environment.  The variables we are setting are:
# * GCP_PROJECTID - The GCP project that will own the PubSub subscription.
# * GCP_TOPIC - The GCP Pub/Sub topic on which we will be listening for responses.
#
composer-set-variables:
	-gcloud composer environments run $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		variables -- set GCP_PROJECTID $(PROJECT)
	-gcloud composer environments run $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		variables -- set GCP_TOPIC $(TOPIC)

#
# Set a Connection definition in Composer called `rest_serve`.
#
composer-set-connid:
	@echo "Creating the Airflow connection called 'rest_serve'"
	gcloud composer environments run $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		connections -- add \
		--conn-host $(SERV_IP) \
		--conn-port $(SERV_PORT) \
		--conn-type http \
		rest_serve

#
# Set a Connection definition in Composer called `rest_serve`.
# Here we use the IP address of a compute engine that was created to host the Flask app.
#
composer-set-connid-compute-engine:
	@echo "Creating the Airflow connection called 'rest_serve'"
	-gcloud composer environments run $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		connections -- delete \
		rest_serve
	gcloud composer environments run $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT) \
		connections -- add \
		--conn-host $(shell gcloud compute instances describe $(COMPUTE_ENGINE_INSTANCE) --zone=$(REGION)-a --project=$(PROJECT) --format="value(networkInterfaces.networkIP)") \
		--conn-port $(SERV_PORT) \
		--conn-type http \
		rest_serve

#
# Get the URL for composer (Airflow)
#
composer-url:

#
# Create the GCP PubSub topic on which events will be published.
#
topic-create: enable-services
	@echo "#"
	@echo "# Creating the pubsub topic."
	@echo "#"
	-gcloud pubsub topics create $(TOPIC) \
		--project=$(PROJECT)

#
# Delete the GCP PubSub topic on which events will be published.
#
topic-delete:
	-gcloud pubsub topics delete $(TOPIC) \
		--project=$(PROJECT)

#
# Enable GCP API services that will be used in our sample.
#
enable-services:
	@echo "#"
	@echo "# Enabling GCP API services"
	@echo "#"
	gcloud services enable \
		composer.googleapis.com \
		pubsub.googleapis.com \
		artifactregistry.googleapis.com \
		compute.googleapis.com \
		--project=$(PROJECT)

resources-list:
	#
	# Does Composer exist?
	#
	-gcloud composer environments describe $(COMPOSER_ENV) \
		--location=$(REGION) \
		--project=$(PROJECT)
	#
	# Does the topic exist?
	#
	-gcloud pubsub topics describe $(TOPIC) \
		--project=$(PROJECT)

#
# Create a GCP artifact repository.
#
repository-create:
	@echo "#"
	@echo "# Creating the repository called $(REPO_NAME)"
	@echo "#"
	-gcloud artifacts repositories create $(REPO_NAME) \
		--repository-format=docker \
		--location=$(REGION) \
		--project=$(PROJECT)

#
# Delete a GCP artifact repository.
#
repository-delete:
	@echo "#"
	@echo "# Deleting the repository called '$(REPO_NAME)'"
	@echo "#"
	-gcloud artifacts repositories delete $(REPO_NAME) \
		--quiet \
		--location=$(REGION) \
		--project=$(PROJECT)

#
# Run Cloud Build to build a Docker image containing our Flask app.
#
cloud-build:
	@echo "#"
	@echo "# Building the docker image for the app"
	@echo "#"
	gcloud builds submit \
  		--config=cloudbuild.yaml \
  		--substitutions=_REPOSITORY=$(REPO_NAME),_IMAGE=$(IMAGE) . \
		--project=$(PROJECT)

#
# Create a Compute Engine to run our flask app.  A docker image will be
# user to run the app.
#
compute-engine-create:
	@echo "#"
	@echo "# Creating the compute engine instance to run the app"
	@echo "#"
	gcloud compute instances create-with-container $(COMPUTE_ENGINE_INSTANCE) \
    	--container-image $(IMAGE_NAME) \
		--container-env=PORT=5000,GOOGLE_CLOUD_PROJECT=$(PROJECT),GCP_TOPIC=$(TOPIC) \
		--zone=$(REGION)-a \
		--project=$(PROJECT)

#
# Delete the compute engine used to run our flask app.
#
compute-engine-delete:
	@echo "#"
	@echo "# Deleting the compute engine instance that ran the app"
	@echo "#"
	gcloud compute instances delete $(COMPUTE_ENGINE_INSTANCE) \
		--zone=$(REGION)-a \
		--quiet \
		--project=$(PROJECT)

# Surplus
curl:
	curl --request POST \
		--data-binary @data.txt \
		--header "Content-Type: text/plain" \
		http://$(SERV_IP):$(SERV_PORT)/serve?correlid=$(CORRELID)

airflow-init:
	docker-compose up airflow-init

airflow-start:
	docker-compose up

docker-build:
	docker build . -t $(IMAGE_NAME)

docker-run:
	docker run --publish 5000:5000 test1

run:
	export GCP_TOPIC="$(TOPIC)"; \
	export GOOGLE_CLOUD_PROJECT="$(PROJECT)"; \
	python3 app.py