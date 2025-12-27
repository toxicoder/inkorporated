# Environment Configurations

This directory contains environment-specific configuration files for the Inkorporated homelab infrastructure.

## Available Environments

The following environments are supported:

1. **dev** - Development environment
2. **staging** - Staging environment  
3. **autopush** - Autopush environment
4. **uat** - User Acceptance Testing environment
5. **canary** - Canary environment for feature testing
6. **prod** - Production environment
7. **priv** - Private environment for sensitive services

## Configuration Structure

Each environment has two main configuration files:

- `domain-config.yaml` - Domain and service subdomain settings
- `environment-config.yaml` - Environment-specific resource limits, security settings, and deployment parameters

## Usage

To use these configurations:

1. Copy the desired environment directory to your project
2. Customize the domain names and settings as needed
3. Apply the configurations to your deployment pipeline

## Environment Details

### dev
- Purpose: Development and testing
- Resources: Minimal (100m CPU, 128Mi memory)
- Replicas: 1

### staging
- Purpose: Pre-production testing
- Resources: Moderate (200m CPU, 256Mi memory)
- Replicas: 2

### autopush
- Purpose: Automated deployment testing
- Resources: Moderate (200m CPU, 256Mi memory)
- Replicas: 2

### uat
- Purpose: User acceptance testing
- Resources: Higher (500m CPU, 512Mi memory)
- Replicas: 3

### canary
- Purpose: Feature testing with production-like settings
- Resources: Higher (500m CPU, 512Mi memory)
- Replicas: 2

### prod
- Purpose: Production deployment
- Resources: High (1000m CPU, 1Gi memory)
- Replicas: 3 with high availability

### priv
- Purpose: Private/sensitive services
- Resources: Moderate (200m CPU, 256Mi memory)
- Replicas: 1 with enhanced security