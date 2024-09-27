#!/bin/bash

firstSubnet() {
  $_aws $awsConfig ec2 describe-subnets | \
    $_jq '.Subnets[0].SubnetId' | \
    cut -d'"' -f2
}

firstSubnetAZ() {
  $_aws $awsConfig ec2 describe-subnets | \
    $_jq '.Subnets[0].AvailabilityZone' | \
    cut -d'"' -f2
}

createVolume() {
  if [[ -z ${NAMESPACE} ]]; then
      echo 'ERROR: namespace must be provided'
      exit 1
  fi
  volSizeGb=$2
  volId=$($_aws $awsConfig ec2 create-volume \
    --availability-zone $(firstSubnetAZ) \
    --size $volSizeGb \
    --volume-type gp2 | \
    $_jq '.VolumeId' | \
    cut -d'"' -f2)
  $_aws $awsConfig ec2 create-tags \
    --resources $volId \
    --tags Key=eksCluster,Value=$eksClusterName \
      Key=usage,Value=${VOLUME_USAGE} \
      Key=namespace,Value=${NAMESPACE} \
      Key=Name,Value=$eksClusterName-$namespace-${VOLUME_USAGE}
  echo "$volId is created"
}

subnetIds() {
  $_aws $awsConfig ec2 describe-subnets | \
    $_jq '.Subnets[].SubnetId' | \
    head -3 | \
    cut -d'"' -f2 | \
    paste -d$1 -s -
}

tagSubnets() {
  $_aws $awsConfig ec2 create-tags \
    --resources $(subnetIds " ") \
    --tags Key=kubernetes.io/cluster/$eksClusterName,Value=shared
  echo 'subnets are tagged'
}

untagSubnets() {
  $_aws $awsConfig ec2 delete-tags \
    --resources $(subnetIds " ") \
    --tags Key=kubernetes.io/cluster/$eksClusterName,Value=shared
  echo 'subnets are untagged'
}

waitForNodegroupCreation() {
  while : ; do
    clusterStatus=$($_aws $awsConfig eks describe-nodegroup \
      --cluster-name $eksClusterName \
      --nodegroup $eksClusterName-nodegroup-1 | \
      $_jq '.nodegroup.status')
    [[ "$clusterStatus" == '"ACTIVE"' ]] && break
    sleep 5
    echo "waiting for the node group to be created ... $clusterStatus"
  done
  echo 'node group is active'
}

createNodegroup() {
  $_aws $awsConfig eks create-nodegroup \
    --cluster-name $eksClusterName \
    --nodegroup-name $eksClusterName-nodegroup-1 \
    --subnets $(firstSubnet) \
    --node-role arn:aws:iam::$accountId:role/$eksNodeRole \
    --scaling-config minSize=1,maxSize=1,desiredSize=1 \
    --labels type=storage \
    --disk-size 20 \
    --instance-types t3.large \
    --ami-type AL2_x86_64
  echo 'node group is created'
  waitForNodegroupCreation
}

waitForNodegroupDeletion() {
  while : ; do
    ngStatus=$($_aws $awsConfig eks describe-nodegroup \
      --cluster-name $eksClusterName \
      --nodegroup $eksClusterName-nodegroup-1 | \
      $_jq '.nodegroup.status')
    [[ "$ngStatus" != '"DELETING"' ]] && break
    sleep 5
    echo "waiting for the node group to be deleted ... $ngStatus"
  done
  echo 'node group is gone'
}

deleteNodegroup() {
  $_aws $awsConfig eks delete-nodegroup \
    --cluster-name $eksClusterName \
    --nodegroup-name $eksClusterName-nodegroup-1
  echo 'node group is deleted'
  waitForNodegroupDeletion
}

waitForCsiAdddonAddition() {
  while : ; do
    addonStatus=$($_aws $awsConfig eks describe-addon \
      --cluster-name $eksClusterName \
      --addon-name aws-ebs-csi-driver | \
      $_jq '.addon.status')
    [[ "$addonStatus" == '"ACTIVE"' ]] && break
    sleep 5
    echo "waiting for the csi addon to be added ... $addonStatus"
  done
  echo 'csi addon is active'
}

addCsiAddon() {
  $_aws $awsConfig eks create-addon \
    --cluster-name $eksClusterName \
    --addon-name aws-ebs-csi-driver
  echo 'csi addon is added'
  waitForCsiAdddonAddition
}

waitForClusterCreation() {
  while : ; do
    clusterStatus=$($_aws $awsConfig eks describe-cluster --name $eksClusterName | \
      $_jq '.cluster.status')
    [[ "$clusterStatus" == '"ACTIVE"' ]] && break
    sleep 5
    echo "waiting for the cluster to be created ... $clusterStatus"
  done
  echo 'cluster is active'
}

createCluster() {
  $_aws $awsConfig eks create-cluster \
    --name $eksClusterName \
    --kubernetes-version $eksKubernetesVersion \
    --role-arn arn:aws:iam::$accountId:role/$eksClusterRole \
    --resources-vpc-config subnetIds=$(subnetIds ",")
  echo 'cluster is created'
  waitForClusterCreation
  tagSubnets
  createNodegroup
  addCsiAddon
}

waitForClusterDeletion() {
  while : ; do
    clusterStatus=$($_aws $awsConfig eks describe-cluster --name $eksClusterName | \
      $_jq '.cluster.status')
    [[ "$clusterStatus" != '"DELETING"' ]] && break
    sleep 5
    echo "waiting for the cluster to be deleted ... $clusterStatus"
  done
  echo 'cluster is gone'
}

deleteCluster() {
  deleteNodegroup
  untagSubnets
  $_aws $awsConfig eks delete-cluster --name $eksClusterName
  echo 'cluster is deleted'
  waitForClusterDeletion
}
