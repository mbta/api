#!/bin/bash
set -e -x

# other required configuration:
# * APP
# * DOCKER_REPO

BUILD_ARTIFACT=$APP-build.zip

semaphore/build_push.sh

# Create Dockerrun file pointing to ECR image, and zip it up
githash=$(git rev-parse --short HEAD)
# escape slashes in the DOCKER_REPO
repo=$(echo $DOCKER_REPO | sed "s/\//\\\\\//g")

test -d $githash && rm -r $githash
mkdir $githash
sed -e "s/DOCKER_REPO/$repo/g" -e "s/GITHASH/$githash/g" ./semaphore/Dockerrun.aws.json > $githash/Dockerrun.aws.json
cp -r rel/.ebextensions $githash
pushd $githash
zip -r ../$BUILD_ARTIFACT .
popd

rm -r $githash
