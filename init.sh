#!/bin/bash

# Prompt the user to enter domain names and email
echo "Enter your domain names separated by space (e.g., example.com www.example.com):"
read -a domains

echo "Enter your email address for important notifications:"
read email

echo "Enter your app name:"
read app_name

echo "Enter the port numbers separated by space (e.g., 3000 3001 3002):"
read -a ports

# Convert domain array to a space-separated string
domain_string=$(IFS=' ' ; echo "${domains[*]}")

# Determine the operating system and set sed command accordingly
OS=$(uname -s)
case "$OS" in
    Darwin)
        sed_i=("sed" "-i" "")  # macOS
        ;;
    Linux)
        sed_i=("sed" "-i")     # Linux
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Update init-letsencrypt.sh with the provided domains and email
"${sed_i[@]}" "s/domains=(.*)/domains=(${domain_string})/" init-letsencrypt.sh
"${sed_i[@]}" "s/email=\".*\"/email=\"${email}\"/" init-letsencrypt.sh

# Update domains in app.conf file
for domain in "${domains[@]}"; do
    "${sed_i[@]}" "s/example.org/${domain}/g" ./data/nginx/app.conf
done

# Update proxy_pass in location block
"${sed_i[@]}" "s/proxy_pass http:\/\/app;/proxy_pass http:\/\/${app_name};/g" ./data/nginx/app.conf

# Build the upstream configuration
upstream_config=""
for port in "${ports[@]}"; do
    upstream_config+="        server ${app_name}:${port};\n"
done

# Construct the complete upstream block
upstream_block="    upstream ${app_name} {\n${upstream_config}    }\n"

# Create a temporary file to store the updated content
temp_file=$(mktemp)

# Update the app.conf file using awk
awk -v new_block="$upstream_block" '
    BEGIN {block=0}
    /^[[:space:]]*upstream[[:space:]]+app[[:space:]]*{/ {print new_block; block=1; next}
    block && /^[[:space:]]*}/ {block=0; next}
    !block {print}
' ./data/nginx/app.conf > "$temp_file"

# Move the temporary file to replace the original file
mv "$temp_file" ./data/nginx/app.conf

echo "init-letsencrypt.sh and app.conf have been updated with your domain and email."

# Execute the init-letsencrypt.sh script
./init-letsencrypt.sh
