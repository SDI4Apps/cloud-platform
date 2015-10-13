#!/bin/bash

gcloud compute instances create mysdi4apps \
  --image-project ubuntu-os-cloud \
  --image ubuntu-1404-trusty-v20150909a \
  --metadata-from-file user-data=user-data.yaml
