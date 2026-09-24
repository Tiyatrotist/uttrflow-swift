#!/usr/bin/env python3
"""Validates a Boolean entitlement value embedded in a signed bundle."""

import argparse
import plistlib
import sys


class EntitlementError(ValueError):
    """An entitlement's value does not satisfy what a release build requires."""


def read_entitlements(data):
    """Parses a signed bundle's entitlements plist, returning key -> value.

    Empty input (a bundle with no entitlements at all) parses as no keys, so a
    missing-key error is what callers see rather than a parse failure.
    """
    if not data.strip():
        return {}
    try:
        return plistlib.loads(data)
    except Exception as error:
        raise EntitlementError(f"could not parse embedded entitlements as a plist: {error}") from error


def require_true(entitlements, key):
    """Raises unless key is present and its value is Boolean true."""
    if key not in entitlements:
        raise EntitlementError(f"{key} is missing from the embedded entitlements")
    value = entitlements[key]
    if value is not True:
        raise EntitlementError(f"{key} is {value!r}, not Boolean true")


def forbid_true(entitlements, key):
    """Raises only when key is present and its value is Boolean true."""
    if entitlements.get(key) is True:
        raise EntitlementError(f"{key} is Boolean true in the embedded entitlements")


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["require-true", "forbid-true"])
    parser.add_argument("key")
    parser.add_argument("--xml", help="path to a file holding the entitlements plist; defaults to stdin")
    arguments = parser.parse_args(argv)

    if arguments.xml:
        with open(arguments.xml, "rb") as handle:
            data = handle.read()
    else:
        data = sys.stdin.buffer.read()

    try:
        entitlements = read_entitlements(data)
        if arguments.mode == "require-true":
            require_true(entitlements, arguments.key)
        else:
            forbid_true(entitlements, arguments.key)
    except EntitlementError as error:
        print(f"entitlement_gate.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
