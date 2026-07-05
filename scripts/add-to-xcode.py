#!/usr/bin/env python3
"""Add Swift source files to the BullNook Xcode project target."""
import sys
import os
from pbxproj import XcodeProject

PROJECT_PATH = "BullNook.xcodeproj/project.pbxproj"
TARGET_NAME = "BullNook"


def add_files(paths):
    project = XcodeProject.load(PROJECT_PATH)
    target = project.get_target_by_name(TARGET_NAME)
    if target is None:
        print(f"Target {TARGET_NAME} not found", file=sys.stderr)
        sys.exit(1)

    added = []
    for path in paths:
        if not os.path.exists(path):
            print(f"File not found: {path}", file=sys.stderr)
            continue
        if not path.endswith(".swift"):
            print(f"Skipping non-Swift file: {path}", file=sys.stderr)
            continue

        # Add file to project if not already present
        file_refs = project.get_files_by_path(path)
        if file_refs:
            print(f"Already in project: {path}")
            continue

        # Determine parent group from directory structure under BullNook/
        parent_group = None
        dir_name = os.path.dirname(path)
        rel_dir = dir_name
        if rel_dir.startswith("BullNook/"):
            rel_dir = rel_dir[len("BullNook/"):]
        if rel_dir and rel_dir != "BullNook":
            parent_group = project.get_or_create_group(rel_dir)

        file_ref = project.add_file(path, parent=parent_group, target_name=TARGET_NAME)
        if file_ref:
            added.append(path)
            print(f"Added: {path}")
        else:
            print(f"Failed to add: {path}", file=sys.stderr)

    if added:
        project.save()
        print(f"Saved project with {len(added)} new file(s)")
    else:
        print("No new files added")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/add-to-xcode.py <file1.swift> [file2.swift] ...", file=sys.stderr)
        sys.exit(1)
    add_files(sys.argv[1:])
