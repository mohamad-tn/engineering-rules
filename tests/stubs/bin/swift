#!/usr/bin/env bash
# Generic tool stub for tests: logs "<tool> <args>" to $STUB_LOG and exits with
# $STUB_EXIT_<TOOL> (default 0). Lets us verify which commands an engine runs
# for toolchains that are not installed in the test environment.
name="$(basename "$0")"
echo "${name} $*" >>"${STUB_LOG:?STUB_LOG must be set}"
var="STUB_EXIT_${name^^}"
var="${var//[-.]/_}"
exit "${!var:-0}"
