#!/bin/bash
# Build a synthetic insights-style archive for testing insights_facts.yml.
# Layout mirrors a real insights-client archive:
#   <top>/data/...        collected command output and config files
#   <top>/meta_data/...   collection metadata
# Usage: make_fixture.sh <output.tar.gz>
set -euo pipefail

out="${1:?usage: $0 <output.tar.gz>}"
out="$(realpath -m "$out")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

top="$tmp/insights-fixture-host-20261104000000"
data="$top/data"
mkdir -p "$data/insights_commands" "$data/etc/insights-client" "$top/meta_data"

echo "fixture-host.example.com"                                          > "$data/insights_commands/hostname_-f"
echo "Linux fixture-host 7.2.15-200.fc44.x86_64 #1 SMP x86_64 GNU/Linux" > "$data/insights_commands/uname_-a"
# Long file name with embedded --qf format string, as in real archives.
printf "bash 5.2.37-1.fc44 x86_64\ncoreutils 9.7-1.fc44 x86_64\nopenssh 10.0p1-1.fc44 x86_64\n" \
  > "$data/insights_commands/rpm_-qa_--qf_NAME_VERSION_RELEASE_ARCH"
echo "Fedora release 44 (Forty Four)"                                    > "$data/etc/redhat-release"
echo "0123456789abcdef0123456789abcdef"                                  > "$data/etc/machine-id"
echo "11111111-2222-3333-4444-555555555555"                              > "$data/etc/insights-client/machine-id"
echo "{}"                                                                > "$top/meta_data/insights.specs.Specs.uname.json"

tar -C "$tmp" -czf "$out" "$(basename "$top")"
echo "wrote $out"
