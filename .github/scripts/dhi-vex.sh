#!/usr/bin/env bash
# Export the Docker Hardened Images (DHI) OpenVEX statements for the exact
# runtime base image a build used, so Trivy can drop findings that DHI has
# triaged as not_affected.
#
# DHI attaches VEX attestations (predicate https://openvex.dev/ns/v0.2.0) to the
# dhi.io base image, not to images built FROM it. Its statements name packages
# by versionless purl (e.g. pkg:apk/alpine/expat), so Trivy also applies them
# to the packages this image inherits from the base.
#
# Usage: BUILD_METADATA='<docker/build-push-action metadata output>' \
#          dhi-vex.sh <platform> <output-file>
# Requires DOCKER_SCOUT_HUB_{USER,PASSWORD} and DOCKER_SCOUT_REGISTRY_{USER,PASSWORD}
# (Docker Hub credentials with dhi.io pull access) and SCOUT_CLI_VERSION.
# Writes file=<output-file> to $GITHUB_OUTPUT, or file= when the base image has
# no VEX attestation; any other failure is fatal.
set -euo pipefail

platform=$1
out=$2
gh_output=${GITHUB_OUTPUT:-/dev/stdout}

base=$(awk 'toupper($1) == "FROM" && toupper($3) == "AS" && $4 == "runtime" { print $2; exit }' Dockerfile)
if [ -z "$base" ]; then
  echo "::error::Dockerfile has no 'FROM <image> AS runtime' stage"
  exit 1
fi
repo=${base%:*}
tag=${base##*:}

# The build's provenance materials record the base image (index) digest it
# resolved. Single-platform builds key them "buildx.build.provenance",
# multi-platform builds "buildx.build.provenance/<platform>".
digest=$(jq -r --arg uri "pkg:docker/${repo}@${tag}?platform=${platform//\//%2F}" \
  '[to_entries[] | select(.key | startswith("buildx.build.provenance")) | .value.materials[]?
    | select(.uri == $uri) | "sha256:" + .digest.sha256] | first // empty' \
  <<<"$BUILD_METADATA")
if [ -z "$digest" ]; then
  echo "::error::no provenance material for ${base} (${platform}) in the build metadata"
  exit 1
fi
ref="${base}@${digest}"

log=$(mktemp)
if docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -e DOCKER_SCOUT_HUB_USER -e DOCKER_SCOUT_HUB_PASSWORD \
  -e DOCKER_SCOUT_REGISTRY_USER -e DOCKER_SCOUT_REGISTRY_PASSWORD \
  -v "$PWD:/work" -w /work "docker/scout-cli:${SCOUT_CLI_VERSION}" \
  vex get "registry://${ref}" --platform "$platform" --output "$out" >"$log" 2>&1; then
  cat "$log"
  echo "Exported $(jq '.statements | length' "$out") DHI VEX statement(s) for ${ref} (${platform})"
  echo "file=${out}" >>"$gh_output"
elif grep -q 'no VEX attestations found' "$log"; then
  cat "$log"
  echo "::notice::${ref} (${platform}) has no DHI VEX attestation; scanning without VEX"
  echo "file=" >>"$gh_output"
else
  cat "$log"
  echo "::error::failed to export DHI VEX for ${ref} (${platform})"
  exit 1
fi
