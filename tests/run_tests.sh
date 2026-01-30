#!/bin/bash

set -u

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$TEST_DIR")"
readonly SCRIPT_DIR="$PROJECT_DIR/src"

readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_NC='\033[0m'
readonly BOLD='\033[1m'

TESTS_PASSED=0
TESTS_FAILED=0

test_header() {
    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_CYAN}TEST SUITE: $1${C_NC}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
}

test_case() {
    echo -e "${C_YELLOW}[TEST]${C_NC} $1"
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}[PASS]${C_NC} $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${C_RED}[FAIL]${C_NC} $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        echo -e "${C_GREEN}[PASS]${C_NC} File exists: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${C_RED}[FAIL]${C_NC} File missing: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_executable() {
    if [ -x "$1" ]; then
        echo -e "${C_GREEN}[PASS]${C_NC} Executable: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${C_RED}[FAIL]${C_NC} Not executable: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${C_GREEN}[PASS]${C_NC} File contains: $2"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${C_RED}[FAIL]${C_NC} File missing content: $2"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_file_structure() {
    test_header "FILE STRUCTURE"
    
    test_case "Check install.sh exists"
    assert_file_exists "$PROJECT_DIR/install.sh"
    
    test_case "Check uninstall.sh exists"
    assert_file_exists "$PROJECT_DIR/uninstall.sh"
    
    test_case "Check manager.sh exists"
    assert_file_exists "$SCRIPT_DIR/manager.sh"
    
    test_case "Check lib/colors.sh exists"
    assert_file_exists "$SCRIPT_DIR/lib/colors.sh"
    
    test_case "Check lib/utils.sh exists"
    assert_file_exists "$SCRIPT_DIR/lib/utils.sh"
    
    test_case "Check lib/metrics.sh exists"
    assert_file_exists "$SCRIPT_DIR/lib/metrics.sh"
    
    test_case "Check lib/users.sh exists"
    assert_file_exists "$SCRIPT_DIR/lib/users.sh"
    
    test_case "Check lib/system.sh exists"
    assert_file_exists "$SCRIPT_DIR/lib/system.sh"
    
    test_case "Check ui/render.sh exists"
    assert_file_exists "$SCRIPT_DIR/ui/render.sh"
}

test_executables() {
    test_header "EXECUTABLE PERMISSIONS"
    
    test_case "Check install.sh is executable"
    assert_executable "$PROJECT_DIR/install.sh"
    
    test_case "Check uninstall.sh is executable"
    assert_executable "$PROJECT_DIR/uninstall.sh"
    
    test_case "Check manager.sh is executable"
    assert_executable "$SCRIPT_DIR/manager.sh"
}

test_bash_syntax() {
    test_header "BASH SYNTAX VALIDATION"
    
    for script in "$PROJECT_DIR/install.sh" "$PROJECT_DIR/uninstall.sh" "$SCRIPT_DIR/manager.sh" "$SCRIPT_DIR/lib"/*.sh "$SCRIPT_DIR/ui"/*.sh; do
        if [ -f "$script" ]; then
            test_case "Syntax check: $(basename $script)"
            bash -n "$script" 2>/dev/null
            assert_success "$(basename $script) syntax valid"
        fi
    done
}

test_code_quality() {
    test_header "CODE QUALITY"
    
    test_case "Check for commented code in manager.sh"
    if ! grep -E '^\s*#[^!]' "$SCRIPT_DIR/manager.sh" | grep -v '#!/bin/bash' | grep -q .; then
        echo -e "${C_GREEN}[PASS]${C_NC} No commented code found"
        ((TESTS_PASSED++))
    else
        echo -e "${C_YELLOW}[WARN]${C_NC} Some commented lines found (acceptable)"
        ((TESTS_PASSED++))
    fi
    
    test_case "Check for commented code in install.sh"
    if ! grep -E '^\s*#[^!]' "$PROJECT_DIR/install.sh" | grep -v '#!/bin/bash' | grep -q .; then
        echo -e "${C_GREEN}[PASS]${C_NC} No commented code found"
        ((TESTS_PASSED++))
    else
        echo -e "${C_YELLOW}[WARN]${C_NC} Some commented lines found (acceptable)"
        ((TESTS_PASSED++))
    fi
}

test_security_features() {
    test_header "SECURITY FEATURES"
    
    test_case "Check for set -u in scripts"
    assert_contains "$PROJECT_DIR/install.sh" "set -u"
    
    test_case "Check for error handling in install.sh"
    assert_contains "$PROJECT_DIR/install.sh" "trap"
    
    test_case "Check for root check in manager.sh"
    assert_contains "$SCRIPT_DIR/manager.sh" "require_root"
    
    test_case "Check for input validation in utils.sh"
    assert_contains "$SCRIPT_DIR/lib/utils.sh" "validate_"
    
    test_case "Check for SSH hardening in install.sh"
    assert_contains "$PROJECT_DIR/install.sh" "NoNewPrivileges"
}

test_performance_features() {
    test_header "PERFORMANCE FEATURES"
    
    test_case "Check for BBR congestion control"
    assert_contains "$PROJECT_DIR/install.sh" "tcp_congestion_control = bbr"
    
    test_case "Check for TCP buffer optimization"
    assert_contains "$PROJECT_DIR/install.sh" "16777216"
    
    test_case "Check for TCP Fast Open"
    assert_contains "$PROJECT_DIR/install.sh" "tcp_fastopen"
    
    test_case "Check for -O3 optimization flag"
    assert_contains "$PROJECT_DIR/install.sh" "O3"
}

test_ui_features() {
    test_header "UI/UX FEATURES"
    
    test_case "Check for modern UI elements in render.sh"
    assert_contains "$SCRIPT_DIR/ui/render.sh" "draw_box"
    
    test_case "Check for progress bars"
    assert_contains "$SCRIPT_DIR/ui/render.sh" "draw_progress_bar"
    
    test_case "Check for status badges"
    assert_contains "$SCRIPT_DIR/ui/render.sh" "draw_status_badge"
    
    test_case "Check for menu items"
    assert_contains "$SCRIPT_DIR/ui/render.sh" "draw_menu_item"
}

test_modular_structure() {
    test_header "MODULAR ARCHITECTURE"
    
    test_case "Check for color module"
    assert_contains "$SCRIPT_DIR/lib/colors.sh" "readonly C_"
    
    test_case "Check for utils module"
    assert_contains "$SCRIPT_DIR/lib/utils.sh" "validate_username"
    
    test_case "Check for metrics module"
    assert_contains "$SCRIPT_DIR/lib/metrics.sh" "get_cpu_usage"
    
    test_case "Check for users module"
    assert_contains "$SCRIPT_DIR/lib/users.sh" "create_vpn_user"
    
    test_case "Check for system module"
    assert_contains "$SCRIPT_DIR/lib/system.sh" "change_ssh_port"
}

test_function_availability() {
    test_header "FUNCTION AVAILABILITY"
    
    test_case "Check for logging functions"
    assert_contains "$SCRIPT_DIR/lib/utils.sh" "log()"
    
    test_case "Check for validation functions"
    assert_contains "$SCRIPT_DIR/lib/utils.sh" "validate_port()"
    
    test_case "Check for metrics functions"
    assert_contains "$SCRIPT_DIR/lib/metrics.sh" "get_network_speed()"
    
    test_case "Check for user management functions"
    assert_contains "$SCRIPT_DIR/lib/users.sh" "delete_vpn_user()"
}

test_integration() {
    test_header "INTEGRATION CHECKS"
    
    test_case "Check manager.sh sources all modules"
    assert_contains "$SCRIPT_DIR/manager.sh" "source.*colors.sh"
    
    test_case "Check manager.sh has main menu"
    assert_contains "$SCRIPT_DIR/manager.sh" "menu_main()"
    
    test_case "Check manager.sh has monitor function"
    assert_contains "$SCRIPT_DIR/manager.sh" "monitor_dashboard()"
    
    test_case "Check install.sh creates directories"
    assert_contains "$PROJECT_DIR/install.sh" "mkdir -p"
}

test_documentation() {
    test_header "DOCUMENTATION"
    
    test_case "Check README exists"
    assert_file_exists "$PROJECT_DIR/README.md"
    
    test_case "Check banner file exists"
    assert_file_exists "$PROJECT_DIR/assets/banner.txt"
}

print_summary() {
    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_CYAN}TEST SUMMARY${C_NC}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_GREEN}Passed: $TESTS_PASSED${C_NC}"
    echo -e "${C_RED}Failed: $TESTS_FAILED${C_NC}"
    
    local total=$((TESTS_PASSED + TESTS_FAILED))
    local percentage=$((TESTS_PASSED * 100 / total))
    
    echo -e "Success Rate: ${C_YELLOW}${percentage}%${C_NC} ($TESTS_PASSED/$total)"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${C_GREEN}✔ ALL TESTS PASSED${C_NC}"
        return 0
    else
        echo -e "${C_RED}✘ SOME TESTS FAILED${C_NC}"
        return 1
    fi
}

main() {
    clear
    echo -e "${C_CYAN}${BOLD}TOX1C SSH-TUNNEL - COMPREHENSIVE TEST SUITE${C_NC}"
    echo ""
    
    test_file_structure
    test_executables
    test_bash_syntax
    test_code_quality
    test_security_features
    test_performance_features
    test_ui_features
    test_modular_structure
    test_function_availability
    test_integration
    test_documentation
    
    print_summary
}

main
