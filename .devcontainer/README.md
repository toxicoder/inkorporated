# Devcontainer Configuration

This directory contains configuration files for the development container environment.

## Persistent Volumes

### MCP Cache Volume
The context7 MCP server uses a persistent volume for caching to maintain cache data between container instances.

**Volume Configuration:**
- Volume name: `mcp-cache-volume`
- Mount path: `/home/vscode/.cline/cache`
- This volume persists data even when the container is stopped or removed

**Configuration Details:**
The persistent volume is defined in `.devcontainer/devcontainer.json`:
```json
{
    "type": "volume",
    "source": "mcp-cache-volume",
    "target": "/home/vscode/.cline/cache"
}
```

The context7 MCP server is configured to use this path for its cache directory in `cline_mcp_settings.json`:
```json
"CONTEXT7_CACHE_DIR": "/home/vscode/.cline/cache"
```

This ensures that cached data, including documentation and code examples, persists between development sessions.