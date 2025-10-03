-include .env

.PHONY: gcloud:iam gcloud:config gcloud:workstation drill local

gcloud:iam:
	./gcloud/iam-bootstrap.sh

gcloud:config:
	./gcloud/create-config.sh

gcloud:workstation:
	./gcloud/create-workstation.sh

drill:
	./workstation/drills/guardian-drill.sh

local:
	./local/install.sh