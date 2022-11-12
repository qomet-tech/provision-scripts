#!/bin/bash

_aws=aws
_jq=jq

region=eu-central-1
accountId=951498986477
iamUser=kam
configProfile="${accountId}_$iamUser"
awsConfig="--profile $configProfile --region $region"

eksClusterName=$1
eksKubernetesVersion=1.23

source _provisionLib.sh

shift
"$@"
