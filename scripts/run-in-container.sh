#!/usr/bin/env bash
set -e

# Run any flutter / dart command inside podman container
IMAGE="ghcr.io/cirruslabs/flutter:stable"
WORKSPACE="$(pwd)"

podman run --rm \
  -v flutter-pub-cache:/root/.pub-cache \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace \
  "${IMAGE}" "$@"
