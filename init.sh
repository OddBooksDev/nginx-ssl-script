#!/bin/bash

# 사용자로부터 도메인과 이메일 입력 받기
echo "Enter your domain names separated by space (e.g., example.com www.example.com):"
read -a domains

echo "Enter your email address for important notifications:"
read email

echo "Enter your app name:"
read app_name

echo "Enter the port numbers separated by space (e.g., 3000 3001 3002):"
read -a ports

# 도메인 배열을 공백으로 구분된 문자열로 변환
domain_string=$(IFS=' ' ; echo "${domains[*]}")

# 운영 체제에 따른 sed 명령어 설정
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

# init-letsencrypt.sh 파일 수정
"${sed_i[@]}" "s/domains=(.*)/domains=(${domain_string})/" init-letsencrypt.sh
"${sed_i[@]}" "s/email=\".*\"/email=\"${email}\"/" init-letsencrypt.sh

# app.conf 파일에서 도메인 변경
for domain in "${domains[@]}"; do
    "${sed_i[@]}" "s/example.org/${domain}/g" ./data/nginx/app.conf
done

# location 블록에서 proxy_pass를 업데이트
"${sed_i[@]}" "s/proxy_pass http:\/\/app;/proxy_pass http:\/\/${app_name};/g" ./data/nginx/app.conf

# Build the upstream configuration
upstream_config=""
for port in "${ports[@]}"; do
    upstream_config+="        server localhost:$port;\n"
done

# Construct the complete upstream block
upstream_block="    upstream app {\n$upstream_config    }\n"

# Create a temporary file to store the updated content
temp_file=$(mktemp)

# Update the temp.conf file using awk
awk -v new_block="$upstream_block" '
    BEGIN {block=0}
    /^[[:space:]]*upstream app[[:space:]]*{/ {print new_block; block=1; next}
    block && /^[[:space:]]*}/ {block=0; next}
    !block {print}
' ./data/nginx/app.conf > "$temp_file"

# Move the temporary file to replace the original file
mv "$temp_file" ./data/nginx/app.conf

echo "init-letsencrypt.sh and app.conf have been updated with your domain and email."

# init-letsencrypt.sh 스크립트 실행
# ./init-letsencrypt.sh
