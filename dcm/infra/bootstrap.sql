-- Bootstrap script: run this manually ONCE before the first DCM deploy.
-- This is the "layer zero" equivalent of terraform's S3 state backend.

-- Enable inherited grants (required for GRANT INHERITED statements)
ALTER ACCOUNT SET FEATURE_RBAC_INHERITED_GRANTS = 'ENABLED';

-- Create the DCM infrastructure database (holds the project objects)
CREATE DATABASE IF NOT EXISTS DCM_INFRA;
CREATE SCHEMA IF NOT EXISTS DCM_INFRA.PROJECTS;

-- Create one DCM project object per environment (each tracks its own deployed state)
CREATE DCM PROJECT IF NOT EXISTS DCM_INFRA.PROJECTS.INFRA_DEV
  COMMENT = 'Infrastructure-as-code project for DEV environment';

CREATE DCM PROJECT IF NOT EXISTS DCM_INFRA.PROJECTS.INFRA_PRD
  COMMENT = 'Infrastructure-as-code project for PRD environment';
