#!/bin/bash

# Ensure that AWS CLI, kubectl, and eksctl are installed on the system before executing this script.

# Edit or leave the default values
export NAMESPACE="efs"
export POLICY_NAME="EFSCSIControllerIAMPolicy"
export STORAGECLASS_PATH="./storageClass-efs.yaml"
export SA_NAME="efs-csi-controller-sa"

# eksctl will refer to the AWS profile, so change the below value if you are using a named AWS profile
# If you haven't set any name, then the default name is 'default'
export PROFILE="default"
export AWS_PROFILE=$PROFILE

# Fill out these variables
# The region_name should be the same as that of the cluster region
export REGION="ap-south-1"
export CLUSTER_NAME="IM-Cluster"

# Visit the link https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html 
# and copy the Registry value corresponding to your cluster region
export IMAGE_REPOSITORY="602401143452.dkr.ecr.ap-south-1.amazonaws.com"

echo -e "\nCluster Name: ${CLUSTER_NAME}"
echo -e "\nDo you want to proceed with the above information for EFS? Type \"yes\" or \"no\": " 
read value
if [ "$value" == "yes" ]; then

    # Create an OIDC provider for the cluster
    export OIDC_ID=$(aws eks describe-cluster --profile "$PROFILE" --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
    echo "OIDC ID: ${OIDC_ID}"
    echo -e "\n[CHECKING...] oidc"
    export CHECK=$(aws --profile "$PROFILE" iam list-open-id-connect-providers | grep "${OIDC_ID}")

    if [ -z "$CHECK" ]; then
        echo "Creating OIDC provider..."
        eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --region "$REGION" --approve
    else
        echo "OIDC Provider already exists."
        echo "OIDC ID: ${OIDC_ID}"
    fi

    # Create an IAM policy
    aws iam create-policy \
        --profile "$PROFILE" \
        --policy-name "$POLICY_NAME" \
        --policy-document file://efs-csi-policy.json \

    echo "IAM Policy ARN:" 
    export POLICY_ARN=$(aws iam list-policies --profile "$PROFILE" --query 'Policies[?PolicyName==`'"$POLICY_NAME"'`].Arn' --output text)
    echo "${POLICY_ARN}"

    echo "----------------------------------"

    eksctl create iamserviceaccount \
        --name "$SA_NAME" \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --attach-policy-arn="$POLICY_ARN" \
        --namespace "$NAMESPACE" \
        --approve \
        --override-existing-serviceaccounts 

    # Add the EFS CSI Driver Helm repository
    helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
    helm repo update

    # Install the EFS CSI Driver using Helm
    helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
        --namespace "$NAMESPACE" \
        --set image.repository="$IMAGE_REPOSITORY/eks/aws-efs-csi-driver" \
        --set controller.serviceAccount.create=false \
        --set controller.serviceAccount.name="$SA_NAME"

    echo "Creating storage class..."
    aws --profile "$PROFILE" eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
    kubectl apply -f "$STORAGECLASS_PATH"

    echo "Done."
    
else
    echo -e "See you next time. Good luck!\n" 
    exit
fi
