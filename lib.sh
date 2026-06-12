#!/bin/bash
#
# Utility functions for shell scripts.

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#######################################
# Print error message to stderr.
# Arguments:
#   Message string.
#######################################
err() {
  printf "%s\n" "$*" >&2
}

#######################################
# Print success message to stdout.
# Arguments:
#   Message string.
#######################################
info() {
  printf "${GREEN}%s${NC}\n" "$*"
}

#######################################
# Print warning message to stdout.
# Arguments:
#   Message string.
#######################################
warn() {
  printf "${YELLOW}%s${NC}\n" "$*"
}

#######################################
# Print info message with label to stdout.
# Arguments:
#   Label string.
#   Value string.
#######################################
print_info() {
  printf "%s: ${GREEN}%s${NC}\n" "$1" "$2"
}
