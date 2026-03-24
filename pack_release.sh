#!/bin/bash

# Pack release script for TommoT General Mod Slot Generator
# This script creates a zip file containing all files except hidden files/folders

# Set the output zip filename
ZIP_NAME="Backfire.zip"

# Remove existing zip if it exists
if [ -f "$ZIP_NAME" ]; then
    echo "Removing existing $ZIP_NAME..."
    rm "$ZIP_NAME"
fi

echo "Creating $ZIP_NAME..."

# Create zip excluding hidden files and folders, and shell scripts
# -r: recursive
# -x: exclude pattern
zip -r "$ZIP_NAME" . -x "*/.*" ".*" ".*/*" "*.sh"

# Check if zip creation was successful
if [ $? -eq 0 ]; then
    echo "Successfully created $ZIP_NAME"
    echo "Archive contents:"
    unzip -l "$ZIP_NAME"
else
    echo "Error: Failed to create $ZIP_NAME"
    exit 1
fi