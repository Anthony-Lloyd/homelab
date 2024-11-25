#!/bin/bash

# Input and output file paths
input_file="/etc/config/dhcp"
output_file="/etc/config/dhcp.new"

# Ensure the input file exists
if [[ ! -f $input_file ]]; then
    echo "Input file not found: $input_file"
    exit 1
fi

# Initialize variables
in_host_block=false
current_block=""

# Create a copy of the input file for output
cp "$input_file" "$output_file"

# Process the input file line by line
while IFS= read -r line; do
    if [[ $line == "config host"* ]]; then
        # Start of a host block
        in_host_block=true
        current_block="$line"$'\n'
    elif $in_host_block; then
        if [[ $line =~ ^[[:space:]] ]]; then
            # Add lines belonging to the current block
            current_block+="$line"$'\n'
        else
            # End of the host block
            in_host_block=false

            # Process the current block to create a domain block
            domain_block=$(echo "$current_block" | sed -E '
                s/config host/config domain/;     # Change host to domain
                /list mac/d;                      # Delete any list mac lines
            ')

            # Append the domain block to the output file if it doesn't already exist
            name=$(echo "$domain_block" | grep "option name" | awk '{print $3}')
            ip=$(echo "$domain_block" | grep "option ip" | awk '{print $3}')

            # Check if the domain entry already exists
            if ! grep -q "config domain.*$name" "$output_file"; then
                echo -e "\n$domain_block" >> "$output_file"
            fi

            # Clear the current block to start processing the next one
            current_block=""
        fi
    fi
done < "$input_file"

# Handle the last block if the file ends mid-block
if [[ -n $current_block ]]; then
    domain_block=$(echo "$current_block" | sed -E '
        s/config host/config domain/;    # Change host to domain
        /list mac/d;                     # Delete any list mac lines
    ')

    name=$(echo "$domain_block" | grep "option name" | awk '{print $3}')
    ip=$(echo "$domain_block" | grep "option ip" | awk '{print $3}')

    # Check if the domain entry already exists
    if ! grep -q "config domain.*$name" "$output_file"; then
        echo -e "\n$domain_block" >> "$output_file"
    fi
fi

echo "Updated configuration saved to $output_file"
