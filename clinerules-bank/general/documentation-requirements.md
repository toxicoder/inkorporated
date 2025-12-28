# Documentation Requirements

## Documentation Requirements

- Update relevant documentation in /docs when modifying features
- Keep README.md in sync with new capabilities
- Maintain changelog entries in CHANGELOG.md
- Include inline code comments for complex logic
- Document API endpoints using OpenAPI specifications in /docs/api
- Add usage examples in documentation for new modules or functions
- Ensure all public APIs have JSDoc or equivalent comments
- Create user guides for end-user features in /docs/user
- Document environment setup in SETUP.md
- Include troubleshooting sections in documentation
- Use diagrams (e.g., via Mermaid or PlantUML) for architecture overviews
- Archive outdated documentation in /docs/archive
- Version documentation to match release tags
- Include contribution guidelines in CONTRIBUTING.md
- Document performance benchmarks in /docs/performance
- Add security considerations to relevant docs
- Ensure documentation is searchable with a table of contents

## MCP Configuration Documentation

- Document the centralized configuration management system for MCP servers
- Include details about the new MCP_SERVERS_DISABLED environment variable
- Explain how MCP server enable/disable is now controlled via environment configuration
- Document the separation of sensitive credentials from main settings
- Update documentation to reflect that MCP servers are disabled by default via environment variable
- Include examples of how to enable MCP servers by setting MCP_SERVERS_DISABLED=false
- Document the migration from JSON-based disabled flag to environment-based configuration
- Ensure all MCP server documentation reflects the new configuration approach