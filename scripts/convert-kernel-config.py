#!/usr/bin/env python3
"""
Convert ROCKNIX kernel .config to NixOS structuredExtraConfig format.

Usage:
    python3 convert-kernel-config.py input.conf output.nix

Input format (kernel .config):
    CONFIG_FOO=y
    CONFIG_BAR=m
    # CONFIG_BAZ is not set
    CONFIG_VALUE=123
    CONFIG_STRING="some string"

Output format (Nix structuredExtraConfig):
    FOO = yes;
    BAR = module;
    BAZ = no;
    VALUE = freeform "123";
    STRING = freeform "some string";
"""

import sys
import re
from pathlib import Path


def parse_config_line(line):
    """
    Parse a kernel config line and return (key, value, type).

    Returns:
        tuple: (config_name, nix_value, value_type) or None if line should be skipped
    """
    line = line.strip()

    # Skip empty lines and pure comments (except "is not set")
    if not line or (line.startswith('#') and 'is not set' not in line):
        return None

    # Handle "# CONFIG_FOO is not set" → FOO = no;
    match = re.match(r'#\s*CONFIG_(\w+)\s+is not set', line)
    if match:
        return (match.group(1), 'no', 'bool')

    # Handle "CONFIG_FOO=y" → FOO = yes;
    match = re.match(r'CONFIG_(\w+)=y\s*$', line)
    if match:
        return (match.group(1), 'yes', 'bool')

    # Handle "CONFIG_FOO=m" → FOO = module;
    match = re.match(r'CONFIG_(\w+)=m\s*$', line)
    if match:
        return (match.group(1), 'module', 'tristate')

    # Handle "CONFIG_FOO=n" → FOO = no;
    match = re.match(r'CONFIG_(\w+)=n\s*$', line)
    if match:
        return (match.group(1), 'no', 'bool')

    # Handle "CONFIG_FOO="string"" → FOO = freeform "string";
    match = re.match(r'CONFIG_(\w+)="([^"]*)"', line)
    if match:
        return (match.group(1), f'"{match.group(2)}"', 'string')

    # Handle "CONFIG_FOO=123" (numeric or other) → FOO = freeform "123";
    match = re.match(r'CONFIG_(\w+)=(.+)', line)
    if match:
        value = match.group(2).strip()
        return (match.group(1), f'"{value}"', 'value')

    # Unrecognized line format
    return None


def needs_quoting(name):
    """
    Check if a Nix attribute name needs quoting.
    Names starting with digits or containing special characters must be quoted.
    """
    if not name:
        return True
    # If name starts with digit, needs quoting
    if name[0].isdigit():
        return True
    # If name contains anything other than alphanumeric or underscore, needs quoting
    if not all(c.isalnum() or c == '_' for c in name):
        return True
    return False


def format_attr_name(name):
    """Format attribute name, quoting if necessary."""
    if needs_quoting(name):
        return f'"{name}"'
    return name


def convert_config(input_path, output_path):
    """Convert kernel .config to Nix structuredExtraConfig format."""

    input_file = Path(input_path)
    output_file = Path(output_path)

    if not input_file.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Reading kernel config from: {input_path}")

    # Parse all config lines
    config_options = []
    skipped_lines = 0

    with open(input_file, 'r') as f:
        for line_num, line in enumerate(f, 1):
            result = parse_config_line(line)
            if result:
                config_options.append(result)
            else:
                skipped_lines += 1

    print(f"Parsed {len(config_options)} config options")
    print(f"Skipped {skipped_lines} lines (comments/empty)")

    # Generate Nix output
    print(f"Writing Nix config to: {output_path}")

    with open(output_file, 'w') as f:
        # Write header
        f.write("# NixOS kernel config for Anbernic RG552 (RK3399)\n")
        f.write("# Generated from ROCKNIX kernel configuration\n")
        f.write("# Linux 6.18.20\n")
        f.write("#\n")
        f.write("# DO NOT EDIT MANUALLY - regenerate using scripts/convert-kernel-config.py\n")
        f.write("\n")
        f.write("{ lib, ... }:\n")
        f.write("\n")
        f.write("{\n")
        f.write("  # Kernel configuration options\n")
        f.write("  # Format: lib.kernel.yes/no/module for bools/tristates\n")
        f.write("  #         lib.kernel.freeform \"value\" for strings/numbers\n")
        f.write("\n")

        # Group options by type for better organization
        bool_opts = [(k, v) for k, v, t in config_options if t == 'bool']
        tristate_opts = [(k, v) for k, v, t in config_options if t == 'tristate']
        string_opts = [(k, v) for k, v, t in config_options if t == 'string']
        value_opts = [(k, v) for k, v, t in config_options if t == 'value']

        # Write boolean options (yes/no)
        # Use lib.mkForce to override nixpkgs defaults
        if bool_opts:
            f.write("  # Boolean options\n")
            for key, value in sorted(bool_opts):
                f.write(f"  {format_attr_name(key)} = lib.mkForce lib.kernel.{value};\n")
            f.write("\n")

        # Write tristate options (yes/module/no)
        # Use lib.mkForce to override nixpkgs defaults
        if tristate_opts:
            f.write("  # Tristate options (can be module)\n")
            for key, value in sorted(tristate_opts):
                f.write(f"  {format_attr_name(key)} = lib.mkForce lib.kernel.{value};\n")
            f.write("\n")

        # Write string options
        # Use lib.mkForce to override nixpkgs defaults
        if string_opts:
            f.write("  # String options\n")
            for key, value in sorted(string_opts):
                f.write(f"  {format_attr_name(key)} = lib.mkForce (lib.kernel.freeform {value});\n")
            f.write("\n")

        # Write numeric/other value options
        # Use lib.mkForce to override nixpkgs defaults
        if value_opts:
            f.write("  # Numeric and other value options\n")
            for key, value in sorted(value_opts):
                f.write(f"  {format_attr_name(key)} = lib.mkForce (lib.kernel.freeform {value});\n")
            f.write("\n")

        f.write("}\n")

    print(f"\nConversion complete!")
    print(f"  Total options: {len(config_options)}")
    print(f"  - Boolean: {len(bool_opts)}")
    print(f"  - Tristate: {len(tristate_opts)}")
    print(f"  - String: {len(string_opts)}")
    print(f"  - Values: {len(value_opts)}")


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 convert-kernel-config.py input.conf output.nix", file=sys.stderr)
        print("", file=sys.stderr)
        print("Example:", file=sys.stderr)
        print("  python3 convert-kernel-config.py \\", file=sys.stderr)
        print("    /tmp/distribution/projects/ROCKNIX/devices/RK3399/linux/linux.aarch64.conf \\", file=sys.stderr)
        print("    nixos/kernel-config.nix", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    convert_config(input_path, output_path)


if __name__ == '__main__':
    main()
