#!/bin/bash
set -e

read -p "Enter your domain (e.g., example.org): " domain
read -p "Enter your server name (e.g., app.example.org): " server_name
read -p "Enter your server port (e.g., 3000): " server_port
read -p "Would you like to set up a wildcard SSL certificate for all subdomains? (y/N): " wildcard_decision

# Determine SSL certificate file name based on user input
if [[ "$wildcard_decision" =~ ^[Yy]$ ]]; then
    read -p "Enter the wildcard SSL certificate file name (e.g., *.$domain): " ssl_certificate_file
else
    ssl_certificate_file="$domain"
fi

# Update nginx.conf or specific site configuration to include the new domain and server name
echo "Updating nginx configuration..."
mkdir -p "./conf"
nginx_conf_path="./conf/$server_name.conf"
cat > "$nginx_conf_path" <<EOL
upstream $server_name {
    server $server_name:$server_port;
}

server {
    listen 80;
    server_name $domain;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $domain;
    server_tokens off;

    ssl_certificate /etc/letsencrypt/live/$ssl_certificate_file/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$ssl_certificate_file/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://$server_name;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

echo "Create in conf folder and directly transfer the file to the data/nginx/ path to restart nginx."

echo "SSL certificate setup for $domain with server name $server_name is complete."
