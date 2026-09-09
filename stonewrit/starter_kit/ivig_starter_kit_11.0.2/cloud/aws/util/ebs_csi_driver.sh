#!/bin/bash

# Edit or leave the default values
export POLICY_NAME="AwsEBSCSIDriverPolicy"
export ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole"
export SA_NAME="ebs-csi-controller-sa"

# eksctl will refer to aws profile, so change the below value if you are using a named aws profile
# if you haven't set any name then the default name is default
export PROFILE="default"
export AWS_PROFILE=$PROFILE

# Fill out these variables
# region_name should be same that of the cluster region
export REGION_NAME="us-east-1"
export CLUSTER_NAME="EKS-IM-Cluster"

echo -e "\nCluster Name is: ${CLUSTER_NAME}"
echo -e "\nIf you want to proceed with above informaton, type \"yes\" or \"no\": " 
read value
if [ $value == "yes" ]
then
   
    #Create an OIDC provider for the cluster
    export OIDC_ID=$(aws eks describe-cluster --profile "$PROFILE" --name ${CLUSTER_NAME} --region ${REGION_NAME} --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
    echo "OIDC ID: ${OIDC_ID}"
    echo -e "\n[CHECKING...] oidc"
    export CHECK=$(aws --profile "$PROFILE" iam list-open-id-connect-providers | grep ${OIDC_ID})
    
    if [ -z "$CHECK" ]
    then
        echo " creating OIDC provider"
        eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region ${REGION_NAME} --approve
    else
        echo "OIDC Provider already exists"
        echo "OIDC ID: ${OIDC_ID}"
    fi
    

    #Create an IAM-POLICY and extract POLICY_ARN
    aws iam create-policy \
    --profile $PROFILE \
    --policy-name $POLICY_NAME \
    --policy-document file://ebs_csi_policy.json

    echo " policy arn" 
    export POLICY_ARN=$(aws --profile "$PROFILE" iam list-policies --query 'Policies[?PolicyName==`'"$POLICY_NAME"'`].Arn' --output text)
    echo ${POLICY_ARN}

    #Configure IAM Role for Service Account
    eksctl create iamserviceaccount \
        --name ${SA_NAME} \
        --cluster ${CLUSTER_NAME} \
        --region ${REGION_NAME} \
        --attach-policy-arn=${POLICY_ARN} \
        --role-name ${ROLE_NAME} \
        --namespace kube-system \
        --approve \
        --override-existing-serviceaccounts

    #Save the "ROLE_ARN" as an environment variable
    export ROLE_ARN=$(aws --profile "$PROFILE" iam list-roles --region $REGION_NAME --query 'Roles[?RoleName==`'"$ROLE_NAME"'`].Arn' --output text)
    echo "ROLE ARN:  ${ROLE_ARN}"
    
    #Install CSI
    eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster ${CLUSTER_NAME} \
    --region ${REGION_NAME} \
    --service-account-role-arn ${ROLE_ARN} \
    --force

    echo "Creating storage class"
    aws --profile "$PROFILE" eks update-kubeconfig --region $REGION_NAME --name $CLUSTER_NAME
    kubectl apply -f storageClass-ebs.yaml
    echo "Done.."

else
    echo -e "See you next time, Good Luck.\n" 
    exit
fi
