#!/bin/sh
# Simple assertion helpers for hermes unit tests.
# Source this file; TESTS_PASSED and TESTS_FAILED accumulate across all assertions.

TESTS_PASSED=0
TESTS_FAILED=0

test_case() {
    printf "  %-64s " "$1"
}

_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "PASS"
}

_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL"
    echo "    -> $1"
}

# Run command; pass if exit 0, fail otherwise.
assert_exit_zero() {
    "$@" >/dev/null 2>&1
    _ec=$?
    if [ "$_ec" -eq 0 ]; then _pass; else _fail "expected exit 0, got $_ec (cmd: $*)"; fi
    return 0
}

# Run command; pass if exit non-zero, fail if exit 0.
assert_exit_nonzero() {
    "$@" >/dev/null 2>&1
    _ec=$?
    if [ "$_ec" -ne 0 ]; then _pass; else _fail "expected non-zero exit, got 0 (cmd: $*)"; fi
    return 0
}

# Pass if file contains pattern (grep -q).
assert_file_contains() {
    _f="$1" _p="$2"
    if grep -q "$_p" "$_f" 2>/dev/null; then
        _pass
    else
        _fail "file '$_f' does not contain '$_p'"
    fi
    return 0
}

# Pass if file exists.
assert_file_exists() {
    _f="$1"
    if [ -f "$_f" ]; then _pass; else _fail "file not found: $_f"; fi
    return 0
}

# Pass if directory exists.
assert_dir_exists() {
    _d="$1"
    if [ -d "$_d" ]; then _pass; else _fail "directory not found: $_d"; fi
    return 0
}

test_suite_summary() {
    echo ""
    echo "  $1: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

all_passed() {
    [ "$TESTS_FAILED" -eq 0 ]
}
