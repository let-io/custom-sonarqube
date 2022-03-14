#!/usr/bin/env bash
# SET THE FOLLOWING VARIABLES
# docker hub username
USERNAME=qualtio
# image name
IMAGE=custom-sonarqube
docker build --no-cache -t $USERNAME/$IMAGE:latest .