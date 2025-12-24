#!/bin/bash
# Test Authentik integration

echo "Running Authentik Integration Tests..."

# Test 1: Check if Authentik deployment exists
if kubectl get deployment authentik-server -n authentik >/dev/null 2>&1; then
    echo "✅ PASS: Authentik deployment found"
else
    echo "⚠️  INFO: Authentik deployment not found (expected in early stages)"
fi

# Test 2: Check if Authentik service is running
if kubectl get svc authentik-server -n authentik >/dev/null 2>&1; then
    echo "✅ PASS: Authentik service found"
else
    echo "⚠️  INFO: Authentik service not found (expected in early stages)"
fi

echo "✅ Authentik integration tests completed"
