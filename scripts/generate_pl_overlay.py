#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def extract_amba_pl_body(text: str) -> str:
    marker = "amba_pl: amba_pl {"
    start = text.find(marker)
    if start == -1:
        raise ValueError("Could not find 'amba_pl: amba_pl {' block in pl.dtsi")

    brace_start = text.find("{", start)
    if brace_start == -1:
        raise ValueError("Malformed amba_pl block")

    depth = 0
    end = -1
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index
                break

    if end == -1:
        raise ValueError("Unterminated amba_pl block in pl.dtsi")

    body = text[brace_start + 1:end]
    filtered_lines = []
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("firmware-name ="):
            continue
        filtered_lines.append(line.rstrip())

    return "\n".join(filtered_lines).strip("\n")


def build_overlay(body: str) -> str:
    indented_body = "\n".join(
        ("            " + line) if line else "" for line in body.splitlines()
    )
    return (
        "/dts-v1/;\n"
        "/plugin/;\n\n"
        "/ {\n"
        "    fragment@0 {\n"
        "        target = <&amba>;\n"
        "        __overlay__ {\n"
        f"{indented_body}\n"
        "        };\n"
        "    };\n"
        "};\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate pl-overlay.dts from pl.dtsi")
    parser.add_argument("input", help="Path to pl.dtsi")
    parser.add_argument("output", help="Path to write pl-overlay.dts")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    body = extract_amba_pl_body(input_path.read_text(encoding="utf-8"))
    overlay = build_overlay(body)
    output_path.write_text(overlay, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())