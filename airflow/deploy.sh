#!/bin/bash

BUCKET="dse-infra-dev-us-west-2-mwaa"
ENVIRONMENT="dse-infra-dev-us-west-2-mwaa-environment"

# Copy the dags
for SUBDIR in $(ls dags); do
  if [ $SUBDIR == '__pycache__' ]; then
      continue
  fi
  aws s3 sync dags/$SUBDIR s3://${BUCKET}/dags/$SUBDIR --delete --exclude "*__pycache__*"
done

# Copy the requirements.txt
OLD_VERSION=$(aws mwaa get-environment --name $ENVIRONMENT --query 'Environment.RequirementsS3ObjectVersion' --output text)
OLD_ETAG=$(aws s3api list-object-versions --bucket $BUCKET --prefix requirements.txt --query "Versions[?VersionId=='$OLD_VERSION'].ETag" --output text)
aws s3 cp requirements/requirements.txt s3://${BUCKET}/requirements.txt
NEW_VERSION=$(aws s3api list-object-versions --bucket $BUCKET --prefix requirements.txt --query 'Versions[?IsLatest].[VersionId]' --output text)
NEW_ETAG=$(aws s3api list-object-versions --bucket $BUCKET --prefix requirements.txt --query "Versions[?IsLatest].ETag" --output text)

# Only update if the requirements have changed
if [ $OLD_ETAG != $NEW_ETAG ]; then
    echo "Detected a difference in requirements.txt, updating the environment"
    aws mwaa update-environment --requirements-s3-object-version "$NEW_VERSION" --name $ENVIRONMENT
    echo "New requirements.txt version is ${VERSION_ID}"
fi
