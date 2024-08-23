#!/bin/bash

source="flutterfront/build/web"
destination="static"

# Ensure destination directory exists
if [ ! -d "$destination" ]; then
    echo "Destination directory does not exist"
    # Uncomment the next line to create the destination directory if it doesn't exist
    # mkdir -p "$destination"
fi

# Ensure source directory exists
if [ ! -d "$source" ]; then
    echo "Source directory does not exist"
    exit 1
fi

# Copy files from source to destination
cp -r "$source/." "$destination/"
