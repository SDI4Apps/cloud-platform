#!/bin/bash

gcloud compute instances create sdi4apps-$(date '+%Y%m%d%H%M%S') --description "SDI4Apps platform 1.1" \
  --image-project ubuntu-os-cloud \
  --image ubuntu-1604-xenial-v20161205 \
  --machine-type n1-standard-1 \
  --zone europe-west1-b \
  --metadata-from-file user-data=user-data-xenial.yaml
