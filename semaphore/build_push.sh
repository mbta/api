#!/bin/bash
set -e

# Required configuration:
# * APP
# * DOCKER_REPO

# log into docker hub if credentials are in the environment
if [ -n "$DOCKER_USERNAME" ]; then
  echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
fi

# build docker image and tag it with git hash and aws environment
githash=$(git rev-parse --short HEAD)
docker build --pull -t $APP:latest .
docker tag $APP:latest $DOCKER_REPO:git-$githash

# push images to ECS image repo
docker push $DOCKER_REPO:git-$githash
