#!/bin/bash
set -e -x
BUILD_ARTIFACT=$APP-build.zip

semaphore/build_push.sh

# Create Dockerrun file pointing to ECR image, and zip it up
githash=$(git rev-parse --short HEAD)

mkdir $githash
sed -e "s/DOCKER_REPO/$DOCKER_REPO/g" -e "s/GITHASH/$githash/g" ./semaphore/Dockerrun.aws.json > $githash/Dockerrun.aws.json
cp -r rel/.ebextensions $githash
pushd $githash
zip -r ../$BUILD_ARTIFACT .
popd

rm -r $githash
