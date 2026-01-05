---
layout: doc
---

# Troubleshooting Guide

## Common Issues
1. **Cloudflared Tunnel Issues**
   - Verify tunnel token is correct
   - Check network connectivity to Cloudflare
   - Review pod logs for errors

2. **Authentication Problems**
   - Verify Authentik configuration
   - Check service integration settings
   - Review authentication logs

3. **Storage Issues**
   - Verify Longhorn and NFS CSI drivers
   - Check PVC binding status
   - Review storage capacity

## Debugging Commands
```bash
# Check pod status
kubectl get pods -A

# View logs for a specific pod
kubectl logs -n <namespace> <pod-name>

# Describe a pod for detailed information
kubectl describe pod -n <namespace> <pod-name>

# Check service status
kubectl get svc -A

# Check ingress status
kubectl get ingress -A
```
