#!/usr/bin/env python3
"""Classifies an SUFeedURL value as `https`, `loopback`, or refuses it.

Shared by the bundle gate (`Scripts/bundle.sh`) and the publish gate
(`Scripts/publish.sh`), so the two cannot disagree on what counts as a local feed.
Matches `UpdateController.isAcceptable` in `Sources/Uttrflow/Updates/UpdateController.swift`,
which the runtime reads.

Prints the kind on stdout and exits 0 on success, prints the URL on stderr and
exits 1 on refusal, exits 2 on usage error.
"""

import sys
from urllib.parse import urlparse


def classify(url):
    parsed = urlparse(url)
    if parsed.scheme == "https":
        return "https"
    if parsed.scheme != "http":
        return None
    # urlparse strips the brackets from an IPv6 literal host.
    host = parsed.hostname
    if host in ("127.0.0.1", "localhost", "::1"):
        return "loopback"
    return None


def main(argv):
    if len(argv) != 2:
        print("usage: feed_url_classify.py URL", file=sys.stderr)
        return 2
    result = classify(argv[1])
    if result is None:
        print(f"refused: {argv[1]}", file=sys.stderr)
        return 1
    print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
