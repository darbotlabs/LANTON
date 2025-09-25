# GitHub Copilot Instructions for LANTON

LANTON (Local Agent Network Controller) is a .NET 9 web application that serves as a unified command-center for managing Darbot micro-services running on localhost. It provides port management, reverse-proxy functionality, and a PowerShell CLI interface.

## Repository Structure

- **LanHub/**: Main .NET 9 web application (ASP.NET Core Minimal API)
- **scripts/**: PowerShell validation and utility scripts
- **wrappers/**: Service launcher scripts
- **lib/**: Library components
- **.ps1 files**: PowerShell command-line tools and validation scripts

## Technology Stack

- **.NET 9**: Primary application framework (ASP.NET Core, Minimal API)
- **PowerShell 7+**: Scripting, CLI tools, and validation framework
- **YARP (Yet Another Reverse Proxy)**: For reverse-proxy functionality
- **WebSockets**: For real-time traffic monitoring
- **JSON**: Configuration and data exchange format

## Development Guidelines

### Code Style & Patterns

1. **C# Code**:
   - Use modern C# features (records, pattern matching, nullable reference types)
   - Follow ASP.NET Core Minimal API patterns
   - Use dependency injection for services
   - Implement proper error handling with structured logging

2. **PowerShell Scripts**:
   - Use approved verbs (Get-, Set-, Start-, Stop-, etc.)
   - Include parameter validation and help documentation
   - Follow PowerShell best practices for error handling
   - Use Write-Host with colors for user feedback (Green for success, Red for errors, Yellow for warnings)

3. **API Design**:
   - RESTful endpoints for port management (`/ports`, `/reserve`, `/release`)
   - Use proper HTTP status codes
   - JSON serialization with WriteIndented for readability
   - Implement proper authentication/authorization (Bearer tokens)
   - Configure HttpClient with User-Agent headers and appropriate timeouts

4. **Service Registration Pattern**:
   - Use dependency injection with AddSingleton for services
   - Register HttpClient with named configuration
   - Services should implement proper interfaces for testability
   - Use ILogger for structured logging throughout services

### Project-Specific Conventions

1. **Port Management**:
   - Port allocation should be dynamic and conflict-free
   - Services register/unregister ports through the central hub
   - Port status tracking: AVAILABLE, RUNNING, RESERVED
   - Default port registry is stored in `lan_ports.json` in the root directory
   - Port history is tracked in `history.csv` with format: Timestamp,ServiceName,Port,Action,PID

2. **Service Integration**:
   - Services should integrate via the `/svc/<name>` proxy pattern
   - Each service should have a wrapper script in the `wrappers/` directory
   - Use consistent naming conventions for service identifiers
   - Core services: lan-ui (7070), bitnet (8000), omniparser (8800), flask-gui (5000)
   - LanHub runs on port 7071 and serves as the central coordinator

3. **Configuration**:
   - Use `appsettings.json` for .NET configuration
   - Use `lan_ports.json` for port mapping configuration
   - Environment-specific settings in `appsettings.Development.json`
   - LanHub binds to all interfaces (`http://*:7071`) by default

4. **Testing & Validation**:
   - Use PowerShell scripts for validation (see `run_validations.ps1`)
   - Each validation round should test specific functionality
   - Validation includes: Port Census, Central Config Service, P-Link Wrappers, LANton Web UI
   - Include both unit tests and integration tests
   - Test port allocation, service discovery, and proxy functionality

5. **CLI Interface**:
   - Main CLI script is `lanton.ps1` with comprehensive command support
   - Commands: start/stop (all or specific service), status, logs, watch, network analysis
   - Use proper PowerShell parameter validation with ValidateSet attributes
   - Include SupportsShouldProcess for commands that modify system state

### Build & Development Process

1. **Building**:
   ```bash
   dotnet build                    # Build the solution
   dotnet run --project LanHub     # Run the main application
   ```

2. **Testing**:
   ```powershell
   pwsh run_validations.ps1        # Run full validation suite
   pwsh scripts/dev.ps1 -Command Test-All  # Alternative test command
   ```

3. **Development Workflow**:
   - Use `start_lanton.ps1` or `start_lanton.bat` for quick startup
   - Monitor logs for service registration and port conflicts
   - Test proxy functionality at `http://localhost:7071/svc/<service>`

### Common Patterns to Follow

1. **Error Handling**:
   - Use try-catch blocks with specific exception types
   - Log errors with appropriate severity levels
   - Return meaningful error messages to clients

2. **Async/Await**:
   - Use async/await for I/O operations
   - Prefer `Task<T>` over `Task` when returning values
   - Use `ConfigureAwait(false)` in library code

3. **Resource Management**:
   - Dispose of resources properly (using statements)
   - Monitor port allocation and cleanup
   - Handle service lifecycle events

4. **Security Considerations**:
   - Validate all input parameters
   - Use proper authentication for API endpoints
   - Implement CSRF protection for UI mutations
   - Follow principle of least privilege

### Domain-Specific Knowledge

- **Network Programming**: Understanding of TCP/UDP ports, localhost networking, proxy concepts, and network interface management
- **Service Architecture**: Microservices communication, service discovery, load balancing, and process lifecycle management
- **PowerShell Ecosystem**: Module development, cmdlet creation, cross-platform compatibility, and advanced parameter validation
- **ASP.NET Core**: Minimal APIs, middleware, dependency injection, configuration, and HttpClient usage
- **System Monitoring**: Network interface statistics, process tracking, and service health monitoring

### Core Service Classes

1. **NetworkManagementService**: 
   - Provides network interface enumeration and statistics
   - Handles IPv4/IPv6 address information and MAC address formatting
   - Manages network traffic monitoring and connection tracking

2. **SysinternalsService**:
   - Integrates with external system utilities
   - Handles HTTP client operations with proper timeout configuration
   - Supports system-level diagnostics and monitoring

3. **Port Registry System**:
   - In-memory dictionary storage for port assignments
   - Persistent storage in JSON format
   - CSV-based history tracking with timestamp logging

### Quality Standards

- Code should be production-ready with proper error handling
- All public APIs should include XML documentation comments
- PowerShell scripts should include comment-based help
- Follow SOLID principles in class design
- Maintain backward compatibility when possible

When making changes, ensure they align with the existing architecture and don't break the port management system or service discovery functionality.