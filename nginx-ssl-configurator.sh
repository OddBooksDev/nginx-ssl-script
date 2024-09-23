#!/bin/bash
set -e

# Define error handling function
error_handler() {
    local error_message="$1"
    local last_line="$2"
    local last_error="$3"
    echo "ERROR: ${error_message}"
    echo "Line: ${last_line} - Exit code: ${last_error}"
    exit 1
}

# Trap errors
trap 'error_handler "An error occurred." "$LINENO" "$?"' ERR

read -p "Enter your main domain (e.g., example.com): " domain
read -p "Would you like to setup a wildcard SSL certificate for all subdomains? (y/N): " wildcard_decision
read -p "Enter your server name (e.g., app.example.com): " server_name
read -p "Enter your server port (e.g., 3000): " server_port

if ! [ -x "$(command -v docker compose)" ]; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

# Check if the Docker network exists
network_name="uponati-network"

# Docker 네트워크가 존재하는지 확인하고, 없으면 생성
if ! docker network ls | grep -q "${network_name}"; then
  echo "Docker 네트워크 '${network_name}'가 존재하지 않습니다. 새 네트워크를 생성합니다."
  docker network create ${network_name}
else
  echo "Docker 네트워크 '${network_name}'가 이미 존재합니다."
fi

rsa_key_size=4096
data_path="./data/certbot"
email="" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domain. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domain ..."
path="/etc/letsencrypt/live/$domain"
mkdir -p "$data_path/conf/live/$domain"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domain ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domain && \
  rm -Rf /etc/letsencrypt/archive/$domain && \
  rm -Rf /etc/letsencrypt/renewal/$domain.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $domain ..."
# Add wildcard domain if requested
domain_args="-d $domain"
if [ "$wildcard_decision" = "Y" ] || [ "$wildcard_decision" = "y" ]; then
  domain_args="$domain_args -d *.$domain"
fi

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload

# Updating nginx.conf or site-specific conf to include the new domain and server_name
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

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
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

echo "### Restarting nginx to apply new configuration..."
docker compose exec nginx nginx -s reload

echo "SSL certificate setup for $domain with server name $server_name is complete."
