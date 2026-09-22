#!/usr/bin/env python3
"""Refuses a public issue template that prompts for content the disclosure rule forbids.

This repository's public intake surface is its `.github/ISSUE_TEMPLATE/*.yml` files. Each
one renders, on GitHub, into a form a contributor fills in to open an issue; the answers
go straight into the issue body, which is published as soon as the issue is filed. The
disclosure rule in `AGENTS.md` already polices commits and pull requests, but it cannot
reach the contributor inside the form — by the time a maintainer sees the answer, it is
already a published page on a public repository.

So the check has to live in the form. It reads every template, looks at every textarea
and input field's label, description and placeholder, and refuses any phrase that asks
the contributor to name another product — "other apps", "what tools do you use", "current
alternatives" — because the answer would be the kind of identifying detail the rule
forbids, and the question itself is what invites it.

The rule is not that the form may not mention other products; it is that the form must not
*ask for them*. A field whose label says "What you do today" and whose description says
"the capability or workflow you reach for" passes: the contributor can write "I use a
separate text-expansion tool" or "I type it by hand", both of which are generic. A field
whose description says "Including other apps" fails: a reasonable contributor reads it
and writes a product name, and the form has now handed the rule a problem before a
maintainer saw it.

The audit also requires a publication warning near any field whose id asks what the
contributor does today, so the rule reaches them at the moment they are about to write.
"""

import argparse
import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("issue template audit: PyYAML is required (pip install PyYAML).")

TEMPLATES_DIR = ".github/ISSUE_TEMPLATE"

# Phrases that ask the contributor to name another product. Each must be a regex that
# matches inside a single sentence, because the matches are reported with the line and
# the surrounding sentence as the location.
INVITING = (
    re.compile(r"\bother apps?\b", re.IGNORECASE),
    re.compile(r"\bapps?\s+(?:you|that|which|i\s+use|i\s+have)\b", re.IGNORECASE),
    re.compile(r"\bapps?\s+do\s+you\b", re.IGNORECASE),
    re.compile(r"\bapps?\s+currently\b", re.IGNORECASE),
    re.compile(r"\bwhat apps?\b", re.IGNORECASE),
    re.compile(r"\btools?\s+(?:you|that|which|i\s+use|i\s+have)\b", re.IGNORECASE),
    re.compile(r"\btools?\s+do\s+you\b", re.IGNORECASE),
    re.compile(r"\btools?\s+currently\b", re.IGNORECASE),
    re.compile(r"\bsoftware\s+you\b", re.IGNORECASE),
    re.compile(r"\bsoftware\s+do\s+you\b", re.IGNORECASE),
    re.compile(r"\bproducts?\s+(?:you|that|which)\b", re.IGNORECASE),
    re.compile(r"\balternative apps?\b", re.IGNORECASE),
    re.compile(r"\bcurrent alternatives?\b", re.IGNORECASE),
    re.compile(r"\bwhat alternatives?\b", re.IGNORECASE),
    re.compile(r"\bcompetitors?\b", re.IGNORECASE),
)

# A field whose id asks what the contributor does today needs a publication warning
# beside it: the rule reaches the contributor at the moment they are about to write,
# not after the issue is filed.
WORKFLOW_FIELDS = re.compile(r"\b(?:alternative|alternatives|instead|currently|today|workflow)\b", re.IGNORECASE)

# Phrases that mark a markdown block as a publication warning. The wording can vary, but
# the content must reach the rule in plain language, so the list is the bar rather than
# a precise script: anything that says "may not be published", "do not name", "do not
# publish" or similar lands here.
WARNING = (
    re.compile(r"\bpublication note\b", re.IGNORECASE),
    re.compile(r"\bmay not be published\b", re.IGNORECASE),
    re.compile(r"\bdo not (?:name|publish|describe|include|quote|screenshot|link)\b", re.IGNORECASE),
    re.compile(r"\bno (?:screenshots?|links?|quotes?|pricing|names?)\b", re.IGNORECASE),
    re.compile(r"\bidentifying detail\b", re.IGNORECASE),
    re.compile(r"\bdisclosure rule\b", re.IGNORECASE),
)


def field_text(item):
    """Every word a contributor reads before they fill in a textarea or input."""
    attributes = item.get("attributes") or {}
    parts = [item.get("id") or "", attributes.get("label") or ""]
    for key in ("description", "placeholder"):
        if attributes.get(key):
            parts.append(attributes[key])
    return "\n".join(filter(None, parts))


def inviting_in(text):
    """Yields one matched phrase per regex; one finding per field collects them all."""
    seen = set()
    for pattern in INVITING:
        match = pattern.search(text)
        if match and match.group(0).lower() not in seen:
            seen.add(match.group(0).lower())
            yield match.group(0)


def warning_in(text):
    """True if any WARNING phrase matches in `text`."""
    return any(pattern.search(text) for pattern in WARNING)


def scan_template(path):
    """Yields (path, line, finding) for each violation in one template.

    `line` is the 1-indexed line in the rendered YAML where the offending text begins,
    reported so the message points at the field rather than at the script.
    """
    try:
        with open(path, errors="ignore") as handle:
            document = yaml.safe_load(handle.read())
    except yaml.YAMLError as error:
        yield path, 0, f"could not be parsed as YAML ({error})"
        return
    if not isinstance(document, dict) or not isinstance(document.get("body"), list):
        # A file under `.github/ISSUE_TEMPLATE/` without a `body` list is the form
        # chooser config (`config.yml`) or a link, not a contributor form, so it does
        # not invite content and is not what this audit polices.
        return

    last_warning_line = 0
    body = document["body"]
    for index, item in enumerate(body):
        kind = item.get("type")
        if kind == "markdown":
            value = (item.get("attributes") or {}).get("value") or ""
            if warning_in(value):
                # Mark the line where the warning began, so the next workflow field can
                # say whether the warning came before it in the rendered form.
                line = value_line(path, value)
                last_warning_line = max(last_warning_line, line)
            continue
        if kind not in ("textarea", "input"):
            continue
        field_id = item.get("id") or f"(body[{index}])"
        text = field_text(item)
        if not text:
            continue
        matches = list(inviting_in(text))
        if matches:
            quoted = ", ".join(f"`{phrase}`" for phrase in matches)
            yield path, attribute_line(path, item), (
                f"field `{field_id}` invites product names ({quoted})"
            )
        if kind == "textarea" and WORKFLOW_FIELDS.search(field_id):
            if last_warning_line == 0:
                yield path, attribute_line(path, item), (
                    f"field `{field_id}` asks what the contributor does today "
                    "but the template has no publication warning above it"
                )


def attribute_line(path, item):
    """The rendered-YAML line where the field's attributes begin."""
    attributes = item.get("attributes") or {}
    label = attributes.get("label") or item.get("id") or ""
    needle = label.splitlines()[0].strip()
    if not needle:
        needle = (attributes.get("description") or "").splitlines()[0].strip()
    with open(path, errors="ignore") as handle:
        for number, line in enumerate(handle, start=1):
            if needle and needle in line:
                return number
    return 0


def value_line(path, value):
    """The rendered-YAML line where a markdown block's value begins."""
    needle = value.splitlines()[0].strip()
    with open(path, errors="ignore") as handle:
        for number, line in enumerate(handle, start=1):
            if needle and needle in line:
                return number
    return 0


def scan_tree():
    """Returns the list of findings for every template under `.github/ISSUE_TEMPLATE/`."""
    if not os.path.isdir(TEMPLATES_DIR):
        return [(TEMPLATES_DIR, 0, f"`{TEMPLATES_DIR}` is not a directory in this tree")]
    findings = []
    for name in sorted(os.listdir(TEMPLATES_DIR)):
        if not name.endswith(".yml"):
            continue
        path = os.path.join(TEMPLATES_DIR, name)
        if not os.path.isfile(path):
            continue
        findings.extend(scan_template(path))
    return findings


def report(findings):
    if not findings:
        return
    print("\n  ✗ an issue template invites content the disclosure rule forbids\n", file=sys.stderr)
    for path, line, finding in findings:
        location = f"{path}:{line}" if line else path
        print(f"    {location}  {finding}", file=sys.stderr)
    print(
        "\n    The disclosure rule applies to issues as well as commits. A contributor reading",
        file=sys.stderr,
    )
    print(
        "    the form answers the question they are asked; if the form asks for a product",
        file=sys.stderr,
    )
    print(
        "    name, the answer is published before a maintainer sees it. Rephrase the field",
        file=sys.stderr,
    )
    print(
        "    in terms of the capability or workflow, and put a publication note above it.",
        file=sys.stderr,
    )
    print(
        "    See `AGENTS.md`, \"What must never reach a tracked file\".",
        file=sys.stderr,
    )
    print("", file=sys.stderr)


def self_test():
    """Run invented templates through the scan; print any that misfire; return their count.

    The fixtures live alongside this file so the test is reproducible from a checkout.
    Each entry is (filename, yaml_text, expected_finding_count).
    """
    fixtures = FIXTURES_DIR
    if not os.path.isdir(fixtures):
        print(f"  ✗ self-test: `{fixtures}` is not a directory", file=sys.stderr)
        return 1
    wrong = 0
    for name, text, expected in SELF_TEST_FIXTURES:
        path = os.path.join(fixtures, name)
        with open(path, "w") as handle:
            handle.write(text)
        actual = len(list(scan_template(path)))
        if actual != expected:
            wrong += 1
            print(
                f"  ✗ self-test: {name} produced {actual} finding(s), expected {expected}",
                file=sys.stderr,
            )
        os.remove(path)
    return wrong


# A self-test fixture is written into a scratch directory under TEMPLATES_DIR for the
# duration of the run. Each row is a (filename, yaml_text, expected_finding_count) tuple.
SELF_TEST_FIXTURES = (
    (
        "_audit_fixture_passing.yml",
        "name: passing\nbody:\n"
        "  - type: markdown\n"
        "    attributes:\n"
        "      value: |\n"
        "        **Publication note.** What you write here is published.\n"
        "  - type: textarea\n"
        "    id: alternatives\n"
        "    attributes:\n"
        "      label: What you do today\n"
        "      description: The capability or workflow you reach for.\n",
        0,
    ),
    (
        "_audit_fixture_other_apps.yml",
        "name: failing\nbody:\n"
        "  - type: textarea\n"
        "    id: alternatives\n"
        "    attributes:\n"
        "      label: What you do instead today\n"
        "      description: Including other apps. Knowing what already works is useful.\n",
        2,
    ),
    (
        "_audit_fixture_what_apps.yml",
        "name: failing\nbody:\n"
        "  - type: textarea\n"
        "    id: tools\n"
        "    attributes:\n"
        "      label: Tools\n"
        "      description: What apps do you use?\n",
        1,
    ),
    (
        "_audit_fixture_no_warning.yml",
        "name: failing\nbody:\n"
        "  - type: textarea\n"
        "    id: alternatives\n"
        "    attributes:\n"
        "      label: What you do instead today\n"
        "      description: The capability or workflow you reach for.\n",
        1,
    ),
    (
        "_audit_fixture_bug_report.yml",
        "name: bug\nbody:\n"
        "  - type: textarea\n"
        "    id: anything-else\n"
        "    attributes:\n"
        "      label: Anything else\n"
        "      description: Console output, a screen recording, whatever you have.\n",
        0,
    ),
)

FIXTURES_DIR = os.path.join(".github", "ISSUE_TEMPLATE")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="prove the audit reports each invented violation exactly when expected",
    )
    options = parser.parse_args()

    if options.self_test:
        wrong = self_test()
        if wrong:
            print(
                f"\nissue template audit: self-test failed on {wrong} fixture(s); the audit"
                "\nis no longer reporting what it should. Fix the audit.\n",
                file=sys.stderr,
            )
            return 1
        print("\nissue template audit: self-test passed on every fixture.\n")
        return 0

    findings = scan_tree()
    if findings:
        report(findings)
        return 1
    templates = [
        name
        for name in sorted(os.listdir(TEMPLATES_DIR))
        if name.endswith(".yml") and os.path.isfile(os.path.join(TEMPLATES_DIR, name))
    ]
    print(
        f"\n  ✓ {len(templates)} issue template(s); none invite content the disclosure rule forbids"
    )
    print("    every textarea and input asks for the capability or workflow, not the product")
    return 0


if __name__ == "__main__":
    sys.exit(main())