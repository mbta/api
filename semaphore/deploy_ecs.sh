#!/bin/bash
set -e -u

# uncomment to debug
set -x

# monitor ECS service for deployment status.
# h/t to this blog post for inspriration:
# https://medium.com/@aaron.kaz.music/monitoring-the-health-of-ecs-service-deployments-baeea41ae737

# this script should be called with an aws environment name (dev / dev-green / prod)
# other required configuration:
# * AWS_REGION
# * APP
# * DOCKER_REPO

## Install later version of aws cli (in particular, to get secretOptions)
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
./awscli-bundle/install -b ~/bin/aws
PATH=~/bin:$PATH

function check_deployment_complete() {
  # extract task counts and test whether they match the desired state

  local deployment_details
  local desired_count
  local pending_count
  local running_count
  deployment_details="${1}"

  # get and print current task counts
  desired_count="$(echo "${deployment_details}" | jq -r '.desiredCount')"
  pending_count="$(echo "${deployment_details}" | jq -r '.pendingCount')"
  running_count="$(echo "${deployment_details}" | jq -r '.runningCount')"
  echo "Desired count: ${desired_count}"
  echo "Pending count: ${pending_count}"
  echo "Running count: ${running_count}"
  # if the number of running tasks equals the number of desired tasks, then we're all set
  [ "${pending_count}" -eq "0" ] && [ "${running_count}" -eq "${desired_count}" ]
}

export AWS_DEFAULT_REGION="${AWS_REGION}"

awsenv="${1}"
appenv="${APP}-${awsenv}"

githash="$(git rev-parse --short HEAD)"

# ensure the image exists on AWS. This command will fail if it does not.
echo "Confirming that image with tag 'git-${githash}' exists in ECR..."
aws ecr describe-images --repository-name "${APP}" --image-ids "imageTag=git-${githash}" > /dev/null && echo "Success."

# get the contents of the template task definition from ECS
# use it as basis for new revision, but replace image with the one built above
echo "Retrieving task definition parameters from ${appenv}-template."
template_task_def="$(aws ecs describe-task-definition --task-definition "${appenv}-template")"
new_containers="$(echo "${template_task_def}" | \
  jq '.taskDefinition.containerDefinitions' | \
  jq --arg gh "${githash}" --arg dr "${DOCKER_REPO}" 'map(.image="\($dr):git-\($gh)")')"

# check to make sure the secrets are included in the new container definition
if (echo "${new_containers}" | jq '.[0] | .secrets' | grep '^null$'); then
  echo "Error: The container definition is missing its 'secrets' block. Deploy cannot proceed."
  exit 1
fi

echo "Publishing new task definition."
aws ecs register-task-definition \
  --family "${appenv}" \
  --task-role-arn "$(echo "${template_task_def}" | jq -r '.taskDefinition.taskRoleArn')" \
  --execution-role-arn "$(echo "${template_task_def}" | jq -r '.taskDefinition.executionRoleArn')" \
  --network-mode "$(echo "${template_task_def}" | jq -r '.taskDefinition.networkMode')" \
  --container-definitions "${new_containers}" \
  --volumes "$(echo "${template_task_def}" | jq '.taskDefinition.volumes')" \
  --placement-constraints "$(echo "${template_task_def}" | jq '.taskDefinition.placementConstraints')" \
  --requires-compatibilities "$(echo "${template_task_def}" | jq -r '.taskDefinition.requiresCompatibilities[]')" \
  --cpu "$(echo "${template_task_def}" | jq -r '.taskDefinition.cpu')" \
  --memory "$(echo "${template_task_def}" | jq -r '.taskDefinition.memory')"

new_task_def="$(aws ecs describe-task-definition --task-definition "${appenv}")"
new_revision="$(echo "${new_task_def}" | jq -r '.taskDefinition.revision')"

# redeploy the cluster
echo "Updating service ${appenv} to use task definition ${new_revision}..."
aws ecs update-service --cluster="${APP}" --service="${appenv}" --task-definition "${appenv}:${new_revision}"

# monitor the cluster for status
deployment_finished=false
while [ "$deployment_finished" = "false" ]; do
  # get the service details
  service_status="$(aws ecs describe-services --cluster="${APP}" --services="${appenv}")"
  # exctract the details for the new deployment (status PRIMARY)
  new_deployment="$(echo "${service_status}" | jq -r '.services[0].deployments[] | select(.status == "PRIMARY")')"

  # check whether the new deployment is complete
  if check_deployment_complete "${new_deployment}"; then
    echo "Deployment complete."
    deployment_finished=true
  else
    # extract deployment id
    new_deployment_id="$(echo "${new_deployment}" | jq -r '.id')"
    # find any tasks that may have stopped unexpectedly
    stopped_tasks="$(aws ecs list-tasks --cluster "${APP}" --started-by "${new_deployment_id}" --desired-status "STOPPED" | jq -r '.taskArns')"
    stopped_task_count="$(echo "${stopped_tasks}" | jq -r 'length')"
    if [ "${stopped_task_count}" -gt "0" ]; then
      # if there are stopped tasks, print the reason they stopped and then exit
      stopped_task_list="$(echo "${stopped_tasks}" | jq -r 'join(",")')"
      stopped_reasons="$(aws ecs describe-tasks --cluster "${APP}" --tasks "${stopped_task_list}" | jq -r '.tasks[].stoppedReason')"
      echo "The deployment failed because one or more containers stopped running. The reasons given were:"
      echo "${stopped_reasons}"
      exit 1
    fi
    # wait, then loop
    echo "Waiting for new tasks to start..."
    sleep 5
  fi
done

# confirm that the old deployment is torn down
teardown_finished=false
while [ "$teardown_finished" = "false" ]; do
  # get the service details
  service_status="$(aws ecs describe-services --cluster="${APP}" --services="${appenv}")"
  # extract the details for any old deployments (status ACTIVE)
  deployment="$(echo "${service_status}" | jq -r --compact-output '.services[0].deployments[] | select(.status == "ACTIVE")')"
  total_tasks=0

  # extract deployment id
  old_deployment_id="$(echo "${deployment}" | jq -r '.id')"
  # count tasks associated with the old deployment that are still running
  running_task_count="$(aws ecs list-tasks --cluster "${APP}" --started-by "${old_deployment_id}" --desired-status "RUNNING" | jq -r '.taskArns | length')"
  total_tasks=$((total_tasks+running_task_count))

  echo "Old tasks still running: ${total_tasks}"
  # if no running tasks, break
  if [ "$total_tasks" -eq "0" ]; then
    echo "Done."
    break
  else
    echo "Waiting for old tasks to be stopped..."
    sleep 5
  fi
done
