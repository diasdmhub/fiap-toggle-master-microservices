#!/usr/bin/env bash
set -e
# Desabilita o pager globalmente para evitar pausa nos comandos aws
export AWS_PAGER=""

# CAPTURA AS VARIÁVEIS DE EXECUÇÃO
source .env

# CARREGA O ARQUIVO DE POLÍTICAS EXTRAS
POLICY_LOAD=$(sed "s/_ACCOUNT_ID_/$ACC_ID/g" toggle-policy.json)

# CRIA O PROVEDOR IAM OPENID PARA O CLUSTER
eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --approve

# CRIA A POLÍTICA EXTRA DA TOGGLEMASTER
aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "$POLICY_LOAD"

# CRIA UMA CONTA DE SERVIÇO GERENCIADA POR OPENID COM AS POLÍTICAS PADRÕES E EXTRAS
eksctl create iamserviceaccount \
  --override-existing-serviceaccounts \
  --name "$SERVICE_ACC_NAME" \
  --namespace "$NAMESPACE" \
  --cluster "$CLUSTER_NAME" \
  --role-name "$ROLE_NAME" \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKSServiceRolePolicy \
  --attach-policy-arn arn:aws:iam::aws:policy/AWSServiceRoleForAmazonEKSNodegroup \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
  --attach-policy-arn arn:aws:iam::"${ACC_ID}":policy/"${POLICY_NAME}" \
  --approve

echo -e "\n\nROLE \"$ROLE_NAME\" CRIADO COM SUCESSO:"
echo "######"
aws iam get-role --role-name "$ROLE_NAME" --query Role.AssumeRolePolicyDocument --output yaml
echo "######"

echo -e "\n\nPOLÍTICAS ASSOCIADAS AO ROLE:"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[].PolicyArn" --output table

echo -e "\n\nCONTA DE SERVIÇO COM A ROLE NA ANOTAÇÃO:"
echo "######"
kubectl describe serviceaccount "$SERVICE_ACC_NAME" -n "$NAMESPACE"