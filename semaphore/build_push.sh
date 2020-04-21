#!/bin/bash
set -e -x -u

# other required configuration:
# * APP
# * DOCKER_REPO

# build docker image and tag it with git hash and aws environment
githash=$(git rev-parse --short HEAD)
docker build --pull -t $APP:latest .
docker tag $APP:latest $DOCKER_REPO:git-$githash

# push images to ECS image repo
docker push $DOCKER_REPO:git-$githash
