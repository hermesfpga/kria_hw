#!/bin/sh
# Run all hermes unit tests.
# Exit code: 0 if all suites pass, 1 if any suite fails.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUITES_FAILED=0

run_suite() {
    _suite="$1"
    if ! sh "$REPO_ROOT/tests/$_suite"; then
        SUITES_FAILED=$((SUITES_FAILED + 1))
    fi
    echo ""
}

echo "========================================="
echo " Hermes fast unit tests"
echo "========================================="

run_suite test_bitstream_loader.sh
run_suite test_overlay_loader.sh
run_suite test_vivado_artifact_validation.sh

echo "========================================="
if [ "$SUITES_FAILED" -eq 0 ]; then
    echo " ALL SUITES PASSED"
    exit 0
else
    echo " $SUITES_FAILED SUITE(S) FAILED"
    exit 1
fi
