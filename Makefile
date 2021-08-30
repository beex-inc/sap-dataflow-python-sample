# Parameters
GCS_BUCKET_NAME :=
PROJECT :=

# GCP Settings
REGION := asia-northeast1
SUBNETWORK=regions/$(REGION)/subnetworks/sapbq-dataflow-subnetwork

# Dataflow Settings
JOB_NAME := sap-companycode-load-sample-job
FLEXTEMPLATE_IMAGE := gcr.io/$(PROJECT)/$(JOB_NAME)-flextemplate:latest
WORKER_IMAGE := gcr.io/$(PROJECT)/$(JOB_NAME)-worker:latest
TEMPLATE_PATH := gs://$(GCS_BUCKET_NAME)/dataflow/template/$(JOB_NAME).json
METADATA_FILE := spec/template_metadata.json

# Job Parameters
SAP_USER := idadmin
SAP_PASSWD := 
SAP_ASHOST := 
SAP_SYSNR := 00
SAP_CLIENT := 800
SAP_LANG := EN
BQ_DATASET := sap_sample_dataset
BQ_TABLE := company_code


validate-vars-project:
ifndef PROJECT
	echo "Plead set PROJECT Variable"
	exit 1
endif

validate-vars-bucket:
ifndef GCS_BUCKET_NAME
	echo "Plead set GCS_BUCKET_NAME Variable"
	exit 1
endif

validate-vars-job:
ifndef SAP_ASHOST
	echo "Plead set SAP_ASHOST Variable"
	exit 1
endif
ifndef SAP_PASSWD
	echo "Plead set SAP_PASSWORD Variable (IDADMIN Password)"
	exit 1
endif

.PHONY: setup-infra
setup-infra:
	bq mk $(BQ_DATASET)
	cd terraform/ && \
	  terraform init && \
	  terraform apply

.PHONY: setup-infra
destroy-infra:
	cd terraform/ && \
	  terraform init && \
	  terraform destroy
	bq rm $(BQ_DATASET).$(BQ_TABLE)
	bq rm $(BQ_DATASET)

.PHONY: build-worker-image
build-worker-image: validate-vars-project 
	docker build --tag $(WORKER_IMAGE) -f Dockerfile.worker .
	gcloud auth configure-docker --project $(PROJECT)
	docker push $(WORKER_IMAGE)

.PHONY: build-flextemplate-image
build-flextemplate-image: validate-vars-project 
	docker build --tag $(FLEXTEMPLATE_IMAGE) -f Dockerfile.flextemplate .
	gcloud auth configure-docker --project $(PROJECT)
	docker push $(FLEXTEMPLATE_IMAGE)

.PHONY: build
build: validate-vars-project validate-vars-bucket build-flextemplate-image build-worker-image
	gcloud dataflow flex-template build $(TEMPLATE_PATH) \
		--project $(PROJECT) \
		--image "$(FLEXTEMPLATE_IMAGE)" \
		--metadata-file "$(METADATA_FILE)" \
		--sdk-language "PYTHON"

.PHONY: start-job
start-job: validate-vars-project validate-vars-bucket validate-vars-job 
	gcloud dataflow flex-template run "$(JOB_NAME)-`date +%Y%m%d-%H%M%S`" \
		--project=$(PROJECT) \ 
		--region=$(REGION) \ 
		--subnetwork=$(SUBNETWORK) \ 
		--template-file-gcs-location="$(TEMPLATE_PATH)" \
		--staging-location="gs://$(GCS_BUCKET_NAME)/dataflow/staging" \
		--additional-experiments=use_runner_v2 \
		--disable-public-ips \
		--parameters base-bucket="$(GCS_BUCKET_NAME)" \
		--parameters job-project=$(PROJECT) \
        --parameters job-name=$(JOB_NAME) \
		--parameters sap-ashost=$(SAP_ASHOST) \
		--parameters sap-user=$(SAP_USER) \
		--parameters sap-passwd=$(SAP_PASSWD) \
		--parameters sap-sysnr=$(SAP_SYSNR) \
		--parameters sap-lang=$(SAP_LANG) \
		--parameters sap-client=$(SAP_CLIENT) \
		--parameters bq-dataset=$(BQ_DATASET) \
		--parameters bq-table=$(BQ_TABLE)
