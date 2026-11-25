#!/usr/bin/env bash
# Checks that a pull request title follows Conventional Commits.
# Usage: check-commit-msg.sh "<title>"
subject=$1
types='feat|fix|perf|refactor|test|docs|build|ci|chore'
scopes='parser|book|cli|bench'
pattern="^($types)(\(($scopes)\))?: [^ ].*$"

if [[ ! $subject =~ $pattern ]]; then
    echo "error: '$subject' is not a Conventional Commit" >&2
    echo "  expected: <type>[(<scope>)]: <description>" >&2
    echo "  types:    ${types//|/ }" >&2
    echo "  scopes:   ${scopes//|/ } (optional)" >&2
    exit 1
fi
if (( ${#subject} > 72 )); then
    echo "error: '$subject' is ${#subject} characters, at most 72" >&2
    exit 1
fi
