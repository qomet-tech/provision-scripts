#!/bin/bash

_aws=aws
_jq=jq

region=${REGION}
accountId=${ACCOUNT_ID}
iamUser=${IAM_USER}
configProfile=${CONFIG_PROFILE}
awsConfig="--profile $configProfile --region $region"
eksClusterName=${CLUSTER}
eksKubernetesVersion=1.23

echo
echo '------------------------------------------------'
echo "region: $region"
echo "accountId: $accountId"
echo "iamUser: $iamUser"
echo "configProfile: $configProfile"
echo "awsConfig: $awsConfig"
echo "eksClusterName: $eksClusterName"
echo "eksKubernetesVersion: $eksKubernetesVersion"
echo '------------------------------------------------'
echo

source provision-scripts/_provisionLib.sh

"$@"
