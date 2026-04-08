# Implementation Plan: Inkorporated Codebase Refactor

## [Overview]

This implementation plan addresses the comprehensive refactor of the Inkorporated hybrid cloud infrastructure codebase to establish consistency, fill documentation gaps, harden the Bazel build system, and ensure all 30+ Kubernetes services follow standardized patterns.

The Inkorporated project is a hybrid cloud infrastructure-as-code repository that deploys a complete self-hosted homelab/enterprise environment combining Proxmox on-premises infrastructure with AWS/GCP cloud bursting capabilities. The project uses Bazel as its build system, Terraform for infrastructure provisioning, Ansible for configuration management, and ArgoCD for GitOps deployment orchestration.

This refactor addresses four main categories of work:
1. **Directory cleanup** - Resolving duplicate/inconsistently named service directories
2. **Documentation creation** - Adding missing style guides, deployment guides, and environment configuration templates
3. **Bazel hardening** - Ensuring complete test coverage with proper BUILD file structure across all test directories
4. **Service standardization** - Documenting and enforcing consistent deployment patterns across all 30+ services

---

## [Types]

This plan focuses on architectural and conventional types rather than traditional programming language types, as this is primarily an infrastructure-as-code configuration project.

### Service Manifest Sequence Type

Each Kubernetes service follows this standardized manifest order:
```
1. Namespace.yaml      - Creates isolated namespace
2. Deployment.yaml     - Application deployment with replicas
3. Service.yaml        - Internal cluster service (ClusterIP)
4. Ingress.yaml        - External access (optional)
5. ConfigMap.yaml      - Non-sensitive configuration (optional)
6. Secret.yaml         - Sensitive data reference (optional)
7. PodDisruptionBudget.yaml - High availability requirements (optional)
```

### Environment Configuration Hierarchy

```
config/environments/<env>/environment-config.yaml
    └── apps/shared/<service>/Deployment.yaml
         └── apps/environments/<env>/<service>/ (overrides, if any)
```

### Bazel Test Target Pattern

```python
sh_test(
    name = "<test_name>",
    srcs = ["<test_script>.sh"],
    data = [                      # Direct labels only - no glob()
        "<file1>",
        "<file2>",
    ],
    tags = ["manual"],            # Optional: if binary not always available
    args = [...],                  # Optional: script arguments
)
```

---

## [Files]

### New Files to Create:

#### 1. `.devcontainer/.env.example`
**Purpose**: Template for sensitive configuration variables with examples and defaults.

#### 2. `docs/guides/domain_templating.md`
**Purpose**: Documentation for ArgoCD environment variable templating using `{{ .Env.VAR_NAME }}` syntax.

#### 3. `docs/guides/service_deployment.md`
**Purpose**: Standard deployment manifest sequence, resource recommendations, and guidelines.

#### 4. `docs/style_guides/infra_style_guide.md`
**Purpose**: Terraform and Ansible coding standards for consistent infrastructure code.

#### 5. `tests/deployment/BUILD.bazel`
**Purpose**: Bazel BUILD target for Helm validation tests.

#### 6. `tests/integration/BUILD.bazel`
**Purpose**: Bazel BUILD target for service integration tests.

#### 7. `tests/kubernetes/BUILD.bazel`
**Purpose**: Bazel BUILD target for Kubernetes manifest validation.

#### 8. `tests/security/BUILD.bazel`
**Purpose**: Bazel BUILD target for security permission tests.

#### 9. `tests/BUILD.bazel`
**Purpose**: Aggregated BUILD target that consolidates all subdirectory test targets.

### Files to Modify:

#### 1. `BUILD.bazel` (root)
**Changes**:
- Add file-level docstring
- Update import paths
- Add `config:all_configs` target reference

#### 2. `tests/config/BUILD.bazel`
**Changes**:
- Replace `glob()` in data attributes with direct labels (per AGENTS.md rules)
- Add file-level docstring

#### 3. `infrastructure/terraform/BUILD.bazel`
**Changes**:
- Replace `glob()` in data attributes
- Add file-level docstring

#### 4. `infrastructure/ansible/BUILD.bazel`
**Changes**:
- Update `glob()` to use `allow_empty=True` pattern
- Add file-level docstring

#### 5. `AGENTS.md`
**Changes**:
- Fix corrupted text at line 95
- Expand sections 4 and 5 with more detail on Bazel and Infrastructure rules

### Files to Delete:

#### 1. `workadventure/` directory (entire)
**Reason**: Only contains a duplicate Ingress.yaml with incomplete configuration.

### Files to Move/Rename:

#### 1. `work-adventure/` → `workadventure/`
**Reason**: Rename to remove hyphen, creating consistent camelCase naming.

---

## [Functions]

### Shell Script Functions Requiring Rich Docstrings:

According to `.clinerules/00-claude-4-sonnet-emulation.md`, all shell functions need comprehensive documentation.

| File | Requirement |
|------|-------------|
| `validate_config.sh` | Verify functions have rich docstrings with parameters, returns, errors sections |
| `validate_domain_config.sh` | Verify functions have rich docstrings |
| `run_all_tests.sh` | Verify functions have rich docstrings |
| `test_env_loader.sh` | Verify functions have rich docstrings |
| `verify_fix.sh` | Verify functions have rich docstrings |

### Docstring Format Required:

```bash
# =============================================================================
# FUNCTION: <name>
# =============================================================================
# Description:
#   Single-line summary of purpose.
#   Optional extended description if needed.
#
# Parameters:
#   $1 - First parameter description
#   $2 - Second parameter description
#
# Returns:
#   0 on success, non-zero on failure.
#
# Errors:
#   Returns 1 if <condition>.
#   Returns 2 if <condition>.
# =============================================================================
<function_name>() {
    <implementation>
}
```

---

## [Classes]

Not applicable for this infrastructure-as-code project. The equivalent "classes" would be:
- **Terraform modules**: `/infrastructure/terraform/modules/` - Network and VM modules
- **Ansible roles**: `/infrastructure/ansible/roles/` - Configuration management roles

---

## [Dependencies]

| Dependency | Current Status | Required Action |
|------------|----------------|-----------------|
| `rules_sh` | In WORKSPACE.bazel, incomplete | Add SHA256 checksum and use official release URL |
| `shellcheck` | Binary required | Document as prerequisite in README.md |
| `terraform` | Binary required | Document as prerequisite in README.md |
| `ansible` | Binary required | Document as prerequisite in README.md |
| `kubectl` | Binary required | Document as prerequisite in README.md |
| `helm` | Binary required | Document as prerequisite in README.md |

### Updated WORKSPACE.bazel Entry:

```python
http_archive(
    name = "rules_sh",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_shell/releases/download/v0.4.0/rules_shell-v0.4.0.tar.gz",
        "https://github.com/bazelbuild/rules_shell/releases/download/v0.4.0/rules_shell-v0.4.0.tar.gz",
    ],
    sha256 = "3e114424a5c7e4fd43e0133cc6ecdfe54e45ae8affa14fadd839f29901424043",
    strip_prefix = "rules_shell-v0.4.0",
)
```

---

## [Testing]

### Current Test Coverage:

| Test Category | Location | Files Tested |
|---------------|----------|--------------|
| Configuration | tests/config/ | env, inheritance, validation |
| Deployment | tests/deployment/ | Helm validation |
| Integration | tests/integration/ | Authentik integration |
| Kubernetes | tests/kubernetes/ | Manifest/quotas testing |
| Security | tests/security/ | Permission tests |

### Required BUILD File Content:

#### tests/BUILD.bazel:
```python
load("@rules_sh//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "all",
    srcs = [],
    deps = [
        "//tests/config:...",
        "//tests/deployment:...",
        "//tests/integration:...",
        "//tests/kubernetes:...",
        "//tests/security:...",
    ],
)
```

### Test Execution:
```bash
bazel test //tests/... --test_output=errors
```

---

## [Implementation Order]

### PHASE 1: CLEANUP (Low Risk) - Steps 1-3

#### Step 1: Delete workadventure/ directory
```bash
rm -rf apps/shared/workadventure/
```

#### Step 2: Rename work-adventure/ to workadventure/
```bash
mv apps/shared/work-adventure/ apps/shared/workadventure/
```

#### Step 3: Update any references to old paths
Search and replace in:
- Documentation files
- Validation scripts
- README files

### PHASE 2: BAZEL HARDENING - Steps 4-11

#### Step 4: Create tests/BUILD.bazel
Create aggregated test target file.

#### Step 5: Create tests/deployment/BUILD.bazel
```python
load("@rules_sh//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "helm_test",
    srcs = ["test_helm.sh"],
    data = glob(["**/*.yaml"], allow_empty = True),
    tags = ["manual"],
)
```

#### Step 6: Create tests/integration/BUILD.bazel
```python
load("@rules_sh//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "authentik_test",
    srcs = ["test_authentik.sh"],
    tags = ["manual"],
)
```

#### Step 7: Create tests/kubernetes/BUILD.bazel
```python
load("@rules_sh//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "manifest_test",
    srcs = ["test_manifests.sh"],
    data = ["//apps/shared:all_manifests"],
)

sh_test(
    name = "quotas_test",
    srcs = ["test_resource_quotas.sh"],
    tags = ["manual"],
)
```

#### Step 8: Create tests/security/BUILD.bazel
```python
load("@rules_sh//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "permissions_test",
    srcs = ["test_permissions.sh"],
    tags = ["manual"],
)
```

#### Step 9: Update tests/config/BUILD.bazel
Remove glob() from data attributes, use direct labels.

#### Step 10: Update infrastructure/terraform/BUILD.bazel
Add file-level docstring, fix glob() pattern.

#### Step 11: Update infrastructure/ansible/BUILD.bazel
Add file-level docstring, ensure allow_empty=True.

### PHASE 3: DOCUMENTATION - Steps 12-16

#### Step 12: Create .devcontainer/.env.example
Template with all required environment variables.

#### Step 13: Create docs/guides/domain_templating.md
ArgoCD templating documentation.

#### Step 14: Create docs/guides/service_deployment.md
Standard deployment patterns documentation.

#### Step 15: Create docs/style_guides/infra_style_guide.md
Terraform and Ansible coding standards.

#### Step 16: Fix AGENTS.md corruption
Fix duplicated text at line 95.

---

## Service Catalog: 30+ Services

### Infrastructure Services (7)
| Service | Purpose | Manifests |
|---------|---------|-----------|
| traefik | Ingress controller | Complete |
| authentik | SSO/OIDC provider | Complete |
| cloudflared | Zero-trust tunnel | Complete |
| coturn | TURN/STUN server | Partial - missing Ingress |
| cloudnativepg | PostgreSQL HA | Complete |
| mongodb | NoSQL database | Complete |
| config | Storage classes | Complete |

### Collaboration Services (6)
| Service | Purpose | Manifests |
|---------|---------|-----------|
| rocket-chat | Team chat | Complete |
| workadventure | 2D virtual office | Complete |
| jitsi | Video conferencing | Complete |
| kasm | Browser workspaces | Complete |
| coder | Cloud IDE | Complete |
| gitea | Git hosting | Complete |

### AI/ML Services (8)
| Service | Purpose | Manifests |
|---------|---------|-----------|
| ollama | Local LLM runner | Complete |
| open-webui | Ollama interface | Complete |
| langflow | Visual LangChain | Complete |
| kokoro | TTS server | Complete |
| docling | Document parsing | Complete |
| perplexica | AI search engine | Complete |
| searxng | Metasearch engine | Complete |
| surfsense | AI research agent | Complete |

### Productivity Services (5)
| Service | Purpose | Manifests |
|---------|---------|-----------|
| appflowy | Collaborative notes | Complete |
| linkwarden | Bookmark manager | Complete |
| homebox | Inventory tracking | Complete |
| home-assistant | Smart home | Complete |
| homepage | User dashboard | Complete |

### Security Services (2)
| Service | Purpose | Manifests |
|---------|---------|-----------|
| vaultwarden | Password manager | Complete |
| hashicorp-vault | Secrets management | Complete |

**Total: 30 services across 5 categories**

---

## Verification Checklist

### After Phase 1 (Cleanup):
- [ ] `ls apps/shared/workadventure/` shows correct files
- [ ] `ls apps/shared/work-adventure/` fails (directory deleted)
- [ ] No broken symlinks or references

### After Phase 2 (Bazel Hardening):
- [ ] `bazel query //tests/...` succeeds
- [ ] `bazel test //tests/config/...` passes
- [ ] No glob() in data attributes (per AGENTS.md)
- [ ] File-level docstrings present in all BUILD files

### After Phase 3 (Documentation):
- [ ] `.devcontainer/.env.example` exists and is complete
- [ ] Domain templating guide explains `{{ .Env.VAR }}` syntax
- [ ] Service deployment guide explains manifest sequence
- [ ] Infrastructure style guide covers Terraform/Ansible
- [ ] AGENTS.md line 95 is fixed