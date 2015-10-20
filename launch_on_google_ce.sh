#!/bin/bash

gcloud compute instances create sdi4apps-$(date '+%Y%m%d%H%M%S') --description "SDI4Apps platform 1.0" \
  --image-project ubuntu-os-cloud \
  --image ubuntu-1404-trusty-v20150909a \
  --machine-type n1-standard-1 \
  --zone europe-west1-c \
  --metadata-from-file user-data=user-data.yaml
