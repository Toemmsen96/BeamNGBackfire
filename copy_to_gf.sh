#!/bin/bash

# Copy directories to BeamNG mod folder
TARGET_DIR="/home/tom/.local/share/BeamNG/BeamNG.drive/current/mods/unpacked/backfire"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy lua directory
if [ -d "lua" ]; then
    cp -r lua "$TARGET_DIR/"
    echo "Copied lua/ to $TARGET_DIR/"
else
    echo "Warning: lua/ directory not found"
fi

# Copy scripts directory
if [ -d "scripts" ]; then
    cp -r scripts "$TARGET_DIR/"
    echo "Copied scripts/ to $TARGET_DIR/"
else
    echo "Warning: scripts/ directory not found"
fi

# Copy modslotgenerator directory
if [ -d "modslotgenerator" ]; then
    cp -r modslotgenerator "$TARGET_DIR/"
    echo "Copied modslotgenerator/ to $TARGET_DIR/"
else
    echo "Warning: modslotgenerator/ directory not found"
fi


echo "Copy completed!"
