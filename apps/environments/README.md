# Environment-Specific Apps

This directory contains environment-specific overrides and configurations for services in the Inkorporated homelab infrastructure.

## Structure

The structure follows the same pattern as the shared services but with environment-specific customizations:

```
apps/environments/
├── dev/
├── staging/
├── autopush/
├── uat/
├── canary/
├── prod/
└── priv/
```

## Purpose

This directory allows you to:

1. Override default configurations for specific environments
2. Add environment-specific services or configurations
3. Maintain consistent deployment patterns across environments
4. Apply different resource limits, security settings, or networking rules per environment

## Usage

To create environment-specific configurations:

1. Create a directory for your target environment (e.g., `apps/environments/prod/`)
2. Copy relevant service directories from `apps/shared/` 
3. Modify the configurations as needed for that environment
4. Apply environment-specific settings in the deployment pipeline

## Environment-Specific Considerations

### dev
- Development-specific configurations
- Lower resource limits
- Debug settings enabled

### staging
- Pre-production configurations
- Standard resource limits
- Testing configurations

### autopush
- Automated deployment configurations
- Same as staging but with autopush logic

### uat
- User acceptance testing configurations
- Higher resource limits
- Additional monitoring

### canary
- Feature testing configurations
- Production-like settings
- Gradual rollout configurations

### prod
- Production configurations
- High availability settings
- Production security policies

### priv
- Private/sensitive service configurations
- Enhanced security settings
- Network isolation policies