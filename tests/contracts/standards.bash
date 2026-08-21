#!/usr/bin/env bash
# =============================================================================
# standards.bash — Contract tests for script quality standards
# =============================================================================
# shellcheck disable=SC2154  # $output is set by bats `run`

# Assert script starts with #!/usr/bin/env bash
# Usage: assert_shebang <script_path>
assert_shebang() {
    local script="$1"
    run head -1 "$script"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

# Assert script contains no emoji codepoints
# Usage: assert_no_emoji <script_path>
assert_no_emoji() {
    local script="$1"
    local count
    count=$(perl -CSD -ne '$n++ if /[\x{1F300}-\x{1F9FF}]/; END { print $n // 0 }' "$script")
    [ "$count" = "0" ]
}
