#!/bin/bash -e

_aws=aws
_jq=jq

region=${REGION}
accountId=${ACCOUNT_ID}
iamUser=${IAM_USER}
configProfile=${CONFIG_PROFILE}
awsConfig="--profile $configProfile --region $region"
eksClusterName=${CLUSTER}
eksKubernetesVersion=1.30
eksClusterRole=${EKS_CLUSTER_ROLE}
eksNodeRole=${EKS_NODE_ROLE}

echo
echo '------------------------------------------------'
echo "region: $region"
echo "accountId: $accountId"
echo "iamUser: $iamUser"
echo "configProfile: $configProfile"
echo "awsConfig: $awsConfig"
echo "eksClusterName: $eksClusterName"
echo "eksKubernetesVersion: $eksKubernetesVersion"
echo "eksClusterRole: $eksClusterRole"
echo "eksNodeRole: $eksNodeRole"
echo '------------------------------------------------'
echo

rootDir=${PWD}
if [ ! -f ${rootDir}/provision-scripts/_provisionLib.sh ]; then
  rootDir=${PWD}/..
 fi

source ${rootDir}/provision-scripts/_provisionLib.sh

"$@"
