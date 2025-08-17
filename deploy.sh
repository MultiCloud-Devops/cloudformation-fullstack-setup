#!/bin/bash
set -euo pipefail

# -------------------------------
# CONFIG
# -------------------------------
STACK_NAME=$2
TEMPLATE_FILE="templates/${STACK_NAME}.yaml"
PARAM_FILE="parameters/${STACK_NAME}.json"
REGION="us-east-1"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Colors for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Timestamp for logs
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/${STACK_NAME}_${TIMESTAMP}.log"

# -------------------------------
# HELP MENU
# -------------------------------
usage() {
  echo -e "${YELLOW}Usage:${NC} $0 {create|update|delete|describe|changeset|plan} STACK_NAME [--yes]"
  exit 1
}

# -------------------------------
# CONFIRMATION FUNCTION
# -------------------------------
confirm() {
  if [[ "${AUTO_CONFIRM:-}" == "true" ]]; then
    return 0
  fi
  read -p "Are you sure you want to proceed with $1 stack [$STACK_NAME]? (y/n): " choice
  [[ "$choice" == "y" || "$choice" == "Y" ]]
}

# -------------------------------
# CREATE STACK
# -------------------------------
create_stack() {
  echo -e "${GREEN} Creating stack: $STACK_NAME${NC}"
  aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" | tee "$LOG_FILE"

  echo " Waiting for stack creation..."
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo -e "${GREEN}🎉 Stack $STACK_NAME created successfully!${NC}"
}

# -------------------------------
# UPDATE STACK
# -------------------------------
update_stack() {
  echo -e "${YELLOW} Updating stack: $STACK_NAME${NC}"
  confirm "UPDATE" || exit 1

  aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" | tee "$LOG_FILE" || {
      echo -e "${RED} No updates are to be performed${NC}"
      exit 0
    }

  echo " Waiting for stack update..."
  aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo -e "${GREEN} Stack $STACK_NAME updated successfully!${NC}"
}

# -------------------------------
# DELETE STACK
# -------------------------------
delete_stack() {
  echo -e "${RED}  Deleting stack: $STACK_NAME${NC}"
  confirm "DELETE" || exit 1

  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION" | tee "$LOG_FILE"

  echo " Waiting for stack deletion..."
  aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo -e "${GREEN} Stack $STACK_NAME deleted successfully!${NC}"
}

# -------------------------------
# DESCRIBE STACK
# -------------------------------
describe_stack() {
  echo -e "${GREEN} Describing stack: $STACK_NAME${NC}"
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" | tee "$LOG_FILE"
}

# -------------------------------
# CHANGESET
# -------------------------------
create_changeset() {
  CHANGESET_NAME="cs-${STACK_NAME}-${TIMESTAMP}"
  echo -e "${YELLOW} Creating Change Set: $CHANGESET_NAME${NC}"

  aws cloudformation create-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" | tee "$LOG_FILE"

  echo " Waiting for Change Set..."
  aws cloudformation wait change-set-create-complete \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --region "$REGION" || {
      echo -e "${RED} Change Set creation failed${NC}"
      exit 1
    }

  aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --region "$REGION"

  echo " Execute with: aws cloudformation execute-change-set --stack-name $STACK_NAME --change-set-name $CHANGESET_NAME"
}

# -------------------------------
# PLAN (Terraform-style Preview)
# -------------------------------
plan_stack() {
  PLAN_NAME="plan-${STACK_NAME}-${TIMESTAMP}"
  echo -e "${YELLOW} Planning stack: $STACK_NAME${NC}"

  aws cloudformation create-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$PLAN_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" >/dev/null

  aws cloudformation wait change-set-create-complete \
    --stack-name "$STACK_NAME" \
    --change-set-name "$PLAN_NAME" \
    --region "$REGION" || true

  echo -e "${GREEN} Plan Output:${NC}"
  aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$PLAN_NAME" \
    --region "$REGION"

  echo " Cleaning up temporary plan..."
  aws cloudformation delete-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$PLAN_NAME" \
    --region "$REGION"
}

# -------------------------------
# MAIN
# -------------------------------
ACTION=$1
shift || true

if [[ "$*" == *"--yes"* ]]; then
  AUTO_CONFIRM=true
else
  AUTO_CONFIRM=false
fi

case "$ACTION" in
  create) create_stack ;;
  update) update_stack ;;
  delete) delete_stack ;;
  describe) describe_stack ;;
  changeset) create_changeset ;;
  plan) plan_stack ;;
  *) usage ;;
esac
