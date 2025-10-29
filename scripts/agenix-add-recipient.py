#!/usr/bin/env python3
"""
Add Age recipients for a host and operator to secrets/keys.nix.

Run this on the machine whose SSH key you want to trust:

    ./scripts/agenix-add-recipient.py --host vermissian

The script:
  * Reads the host Age recipient from /etc/age/recipients.txt or the host SSH key.
  * Reads the operator Age recipient from ~/.config/agenix/keys.pub or ~/.ssh/id_ed25519.pub.
  * Appends both values to the host entry inside secrets/keys.nix (creating the entry if needed).
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
from typing import Dict, List, Optional


def run(
    cmd: List[str],
    *,
    cwd: Optional[pathlib.Path] = None,
    input_text: Optional[str] = None,
) -> str:
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        input=input_text,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        msg = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{cmd[0]} failed: {msg}")
    return result.stdout.strip()


def read_first_line(path: pathlib.Path) -> Optional[str]:
    if not path.exists():
        return None
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    return lines[0] if lines else None


def convert_ssh_to_age(pub_path: pathlib.Path, ssh_to_age: str) -> Optional[str]:
    if not pub_path.exists():
        return None
    data = pub_path.read_text()
    if not data.strip():
        return None
    return run([ssh_to_age], input_text=data)


def render_attrset(data: Dict[str, List[str]], indent: str = "  ") -> str:
    lines = ["{",]
    for key in sorted(data):
        lines.append(f'{indent}"{key}" = [')
        for value in sorted(set(data[key])):
            lines.append(f'{indent}{indent}"{value}"')
        lines.append(f"{indent}];")
    lines.append("}")
    lines.append("")  # trailing newline
    return "\n".join(lines)


def load_header(keys_file: pathlib.Path) -> str:
    if not keys_file.exists():
        return ""
    header_lines: List[str] = []
    with keys_file.open() as fh:
        for line in fh:
            stripped = line.strip()
            if stripped.startswith("#") or stripped == "":
                header_lines.append(line.rstrip("\n"))
            else:
                break
    return ("\n".join(header_lines).rstrip("\n") + "\n") if header_lines else ""


def load_keys(keys_file: pathlib.Path, repo: pathlib.Path) -> Dict[str, List[str]]:
    if not keys_file.exists():
        return {}
    output = run(
        ["nix", "eval", "--json", "--expr", "(import ./secrets/keys.nix)"],
        cwd=repo,
    )
    return json.loads(output)


def main() -> None:
    parser = argparse.ArgumentParser(description="Add Age recipients to secrets/keys.nix")
    default_repo = pathlib.Path(__file__).resolve().parent.parent
    parser.add_argument(
        "--repo",
        default=default_repo,
        type=pathlib.Path,
        help="Repository root (defaults to the project root inferred from the script path)",
    )
    parser.add_argument(
        "--host",
        dest="host_label",
        default=socket.gethostname(),
        help="Top-level key inside secrets/keys.nix to update (defaults to the current hostname)",
    )
    parser.add_argument(
        "--user-label",
        default=None,
        help="Optional additional entry to create for the user's Age key (defaults to none)",
    )
    parser.add_argument(
        "--host-age",
        dest="host_age_file",
        default="/etc/age/recipients.txt",
        help="Path to a file containing the host Age recipient (defaults to /etc/age/recipients.txt)",
    )
    parser.add_argument(
        "--host-ssh-pub",
        dest="host_ssh_pub",
        default="/etc/ssh/ssh_host_ed25519_key.pub",
        help="Fallback SSH public key to convert when host Age file is missing",
    )
    parser.add_argument(
        "--user-age",
        dest="user_age_file",
        default=str(pathlib.Path.home() / ".config/agenix/keys.pub"),
        help="Path to the operator Age public key (defaults to ~/.config/agenix/keys.pub)",
    )
    parser.add_argument(
        "--user-ssh-pub",
        dest="user_ssh_pub",
        default=str(pathlib.Path.home() / ".ssh/id_ed25519.pub"),
        help="Fallback SSH public key to convert when the Age file is missing",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resulting file instead of writing to secrets/keys.nix",
    )
    args = parser.parse_args()

    repo = args.repo.resolve()
    keys_file = repo / "secrets" / "keys.nix"
    if shutil.which("ssh-to-age") is None:
        raise SystemExit("ssh-to-age is required but not found in PATH")

    ssh_to_age = shutil.which("ssh-to-age") or "ssh-to-age"

    host_recipient = read_first_line(pathlib.Path(args.host_age_file))
    if host_recipient is None:
        host_recipient = convert_ssh_to_age(pathlib.Path(args.host_ssh_pub), ssh_to_age)
    if not host_recipient:
        raise SystemExit(
            f"Unable to determine host Age key. Provide --host-age or ensure {args.host_age_file} or {args.host_ssh_pub} exists."
        )

    user_recipient = read_first_line(pathlib.Path(args.user_age_file))
    if user_recipient is None:
        user_recipient = convert_ssh_to_age(pathlib.Path(args.user_ssh_pub), ssh_to_age)
    if not user_recipient:
        raise SystemExit(
            f"Unable to determine user Age key. Provide --user-age or --user-ssh-pub."
        )

    keys_data = load_keys(keys_file, repo)
    keys_data.setdefault(args.host_label, [])
    if host_recipient not in keys_data[args.host_label]:
        keys_data[args.host_label].append(host_recipient)
    if user_recipient not in keys_data[args.host_label]:
        keys_data[args.host_label].append(user_recipient)

    if args.user_label:
        keys_data.setdefault(args.user_label, [])
        if user_recipient not in keys_data[args.user_label]:
            keys_data[args.user_label].append(user_recipient)

    header = load_header(keys_file)
    rendered = render_attrset(keys_data)
    if args.dry_run:
        sys.stdout.write(header + rendered)
        return

    keys_file.parent.mkdir(parents=True, exist_ok=True)
    with keys_file.open("w") as fh:
        fh.write(header)
        fh.write(rendered)

    machine_label = args.host_label
    user_label = args.user_label or f"{socket.gethostname()}:{getpass.getuser()}"
    print(f"Updated {keys_file} with:")
    print(f"  - host ({machine_label}): {host_recipient}")
    print(f"  - user ({user_label}): {user_recipient}")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as err:
        raise SystemExit(str(err))
