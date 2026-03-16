#!/usr/bin/env bash
# =============================================================================
# mock_systemctl.bash — Higher-level DSL wrappers for systemctl mocking
# =============================================================================

# Mock a service as enabled (systemctl is-enabled succeeds)
# Usage: mock_service_enabled <service_name>
mock_service_enabled() {
    local svc="$1"
    mock_command_conditional systemctl "is-enabled ${svc}" 0 0
}

# Mock a service as disabled (systemctl is-enabled fails)
# Usage: mock_service_disabled <service_name>
mock_service_disabled() {
    local svc="$1"
    mock_command_conditional systemctl "is-enabled ${svc}" 1 0
}

# Mock a service as active (systemctl is-active succeeds)
# Usage: mock_service_active <service_name>
mock_service_active() {
    local svc="$1"
    mock_command_conditional systemctl "is-active ${svc}" 0 0
}

# Mock a service as inactive (systemctl is-active fails)
# Usage: mock_service_inactive <service_name>
mock_service_inactive() {
    local svc="$1"
    mock_command_conditional systemctl "is-active ${svc}" 1 0
}
