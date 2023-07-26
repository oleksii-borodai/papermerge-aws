#!/usr/bin/env bash
#set -eux

source .envrc

CODEPIPELINE_STACK_NAME="github-codepipeline"
APPLICATION_STACK_NAME="papermerge"

create-pipeline () {
if [ -z "${GITHUB_TOKEN}" ]
then
  echo "PIPELINE CREATION FAILED!"
        echo "Provide GITHUB_TOKEN in .envrc file"
  exit 1
fi
aws cloudformation create-stack \
        --capabilities CAPABILITY_IAM \
        --stack-name $CODEPIPELINE_STACK_NAME \
        --parameters ParameterKey=GitHubOAuthToken,ParameterValue="${GITHUB_TOKEN}" \
          ParameterKey=GitHubOwner,ParameterValue="${GITHUB_OWNER}" \
          ParameterKey=GitHubRepo,ParameterValue="${GITHUB_REPO}" \
        --template-body file://pipeline.yaml \
        --output text

}

update-pipeline () {
if [ -z "${GITHUB_TOKEN}" ]
then
  echo "PIPELINE CREATION FAILED!"
        echo "Provide GITHUB_TOKEN in .envrc file"
  exit 1
fi
aws cloudformation update-stack \
      --capabilities CAPABILITY_IAM \
      --stack-name $CODEPIPELINE_STACK_NAME \
      --parameters ParameterKey=GitHubOAuthToken,ParameterValue="${GITHUB_TOKEN}" \
        ParameterKey=GitHubOwner,ParameterValue="${GITHUB_OWNER}" \
        ParameterKey=GitHubRepo,ParameterValue="${GITHUB_REPO}" \
      --template-body file://pipeline.yaml
}

stack-id () {
STACK_ID=$(aws cloudformation describe-stacks --stack-name "${APPLICATION_STACK_NAME}" --output text --query 'Stacks[0].StackId' 2>/dev/null)
if [ -z "${STACK_ID}" ]
then
echo "No application stack deployed!"
exit 1
fi
echo $STACK_ID
}

db-status () {
DB_INSTANCE_ARN=$(aws cloudformation describe-stacks --stack-name "$(stack-id)" --query 'Stacks[0].Outputs[?OutputKey==`DBInstanceArn`].OutputValue | [0]' --output text)
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ARN}" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)
if [ -z "${DB_STATUS}" ]
then
echo "DB status: No database"
else
echo "DB status: ${DB_STATUS}"
fi
}

ecs-cluster-arn () {
ECS_CLUSTER_ARN=$(aws cloudformation describe-stacks --stack-name "$(stack-id)" --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterArn`].OutputValue | [0]' --output text)
echo $ECS_CLUSTER_ARN
}

webui-service-status () {
WEBUI_SERVICE_ARN=$(aws cloudformation describe-stacks --stack-name "$(stack-id)" --query 'Stacks[0].Outputs[?OutputKey==`WebUIServiceArn`].OutputValue | [0]' --output text)
WEBUI_SERVICE_STATUS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${WEBUI_SERVICE_ARN} --query 'services[0].status' --output text 2>/dev/null)
WEBUI_SERVICE_CONTAINERS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${WEBUI_SERVICE_ARN} --query 'services[0].runningCount' --output text 2>/dev/null)
if [ -z "${WEBUI_SERVICE_STATUS}" ]
then
echo "WebUI status: No service defined"
else
echo "WebUI status: ${WEBUI_SERVICE_STATUS}, containers running ${WEBUI_SERVICE_CONTAINERS}"
fi
}

worker-service-status () {
WORKER_SERVICE_ARN=$(aws cloudformation describe-stacks --stack-name "$(stack-id)" --query 'Stacks[0].Outputs[?OutputKey==`WorkerServiceArn`].OutputValue | [0]' --output text)
WORKER_SERVICE_STATUS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${WORKER_SERVICE_ARN} --query 'services[0].status' --output text 2>/dev/null)
WORKER_SERVICE_CONTAINERS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${WORKER_SERVICE_ARN} --query 'services[0].runningCount' --output text 2>/dev/null)
if [ -z "${WORKER_SERVICE_STATUS}" ]
then
echo "Worker status: No service defined"
else
echo "Worker status: ${WORKER_SERVICE_STATUS}, containers running ${WORKER_SERVICE_CONTAINERS}"
fi
}

redis-service-status () {
REDIS_SERVICE_ARN=$(aws cloudformation describe-stacks --stack-name "$(stack-id)" --query 'Stacks[0].Outputs[?OutputKey==`RedisServiceArn`].OutputValue | [0]' --output text)
REDIS_SERVICE_STATUS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${REDIS_SERVICE_ARN} --query 'services[0].status' --output text 2>/dev/null)
REDIS_SERVICE_CONTAINERS=$(aws ecs describe-services --cluster $(ecs-cluster-arn) --services ${REDIS_SERVICE_ARN} --query 'services[0].runningCount' --output text 2>/dev/null)
if [ -z "${REDIS_SERVICE_STATUS}" ]
then
echo "Redis status: No service defined"
else
echo "Redis status: ${REDIS_SERVICE_STATUS}, containers running ${REDIS_SERVICE_CONTAINERS}"
fi
}

start () {
aws cloudformation update-stack \
    --capabilities CAPABILITY_IAM \
    --stack-name $(stack-id) \
    --parameters ParameterKey=DesiredCapacity,ParameterValue=1 \
    --use-previous-template \
    --output text > /dev/null
}

stop () {
aws cloudformation update-stack \
    --capabilities CAPABILITY_IAM \
    --stack-name $(stack-id) \
    --parameters ParameterKey=DesiredCapacity,ParameterValue=0 \
    --use-previous-template \
    --output text > /dev/null
}

restart () {
stop
aws cloudformation wait stack-update-complete --stack-name $(stack-id)
start
}

deploy () {
aws cloudformation create-stack \
    --capabilities CAPABILITY_IAM \
    --stack-name ${APPLICATION_STACK_NAME} \
    --parameters ParameterKey=DesiredCapacity,ParameterValue=1 \
    --template-body file://application.yaml \
    --output text > /dev/null
}

destroy () {
aws cloudformation delete-stack \
    --stack-name $(stack-id)
}


status () {
db-status
webui-service-status
worker-service-status
redis-service-status
}



POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --create-pipeline)
      create-pipeline
      shift # past argument
      ;;
    --update-pipeline)
      update-pipeline
      shift # past argument
      ;;
    --start)
      start
      shift # past argument
      ;;
    --stop)
      stop
      shift # past argument
      ;;
    --restart)
      restart
      shift # past argument
      ;;
    --status)
      status
      shift # past argument
      ;;
    --deploy)
      deploy
      shift # past argument
      ;;
    --destroy)
      destroy
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
