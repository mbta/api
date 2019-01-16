#!/bin/bash
set -e -x

# Install DynamoDB local
curl -O https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz
tar -xvf dynamodb_local_latest.tar.gz
nohup java -jar DynamoDBLocal.jar -inMemory -sharedDb &

export MIX_ENV=test

$(dirname $0)/deps_get.sh
mix compile --force --warnings-as-errors

mix coveralls.json -u

bash <(curl -s https://codecov.io/bash)
