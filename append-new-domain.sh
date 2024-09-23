#!/bin/bash
set -e

confirm() {
    while true; do
        echo "Please carefully enter the existing domains :"
        read -p "Enter domains: " existing_domains_input
        IFS=',' read -r -a domains <<< "$existing_domains_input"

        echo "You have entered the following domains: ${domains[@]}"
        echo "Are these correct? (Y/N):"
        read confirmation
        if [[ $confirmation == [Yy] ]]; then
            echo "Great! Let's continue."
            break
        else
            echo "Please re-enter the existing domains."
        fi
    done
}

# Set initial variables
rsa_key_size=4096
data_path="./data/certbot"
email="tsyoon@uponati.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# Confirm the existing domains
confirm

# Ask to add new domain
read -p "Enter new domain to add (or leave blank to skip): " new_domain
if [[ ! -z "$new_domain" ]]; then
  domains+=($new_domain)
fi

# Check if existing data is found
if [ -d "$data_path" ]; then
  read -p "Existing data found for ${domains[*]}. Continue and replace existing certificate? (y/N) " decision
  if [[ "$decision" != "Y" ]] && [[ "$decision" != "y" ]]; then
    exit
  fi
fi

# Download recommended TLS parameters if not already present
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

# Create or update certificates
echo "### Creating or updating certificates for ${domains[@]} ..."
path="/etc/letsencrypt/live/${domains[0]}" # Assume first domain's path for all
mkdir -p "$data_path/conf/live/${domains[0]}"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

# Start nginx
echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx
echo

# Delete dummy certificates and request new ones
echo "### Deleting dummy certificate and requesting new ones for ${domains[@]} ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/${domains[0]} && \
  rm -Rf /etc/letsencrypt/archive/${domains[0]} && \
  rm -Rf /etc/letsencrypt/renewal/${domains[0]}.conf" certbot
echo

# Prepare domain arguments for certbot
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Configure email argument
email_arg="--email $email"

# Enable staging mode if needed
staging_arg=""
if [ "$staging" -ne "0" ]; then
  staging_arg="--staging"
fi

# Run certbot with all domains
certbot_output=$(docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot)

# Check if Certbot command succeeded
if [[ $? -ne 0 ]]; then
    echo "Certbot failed to obtain a certificate, check the log at $certbot_log for more details."
    exit 1
else
    echo "Successfully completed, please check and match the fullchain and privkey below to the corresponding conf file and restart nginx"
fi

# Extract certificate paths if successful
if [[ -n $(echo $certbot_output | grep 'Certificate is saved at') ]]; then
    fullchain_path=$(echo "$certbot_output" | grep -oP 'Certificate is saved at: \K.*')
    privkey_path=$(echo "$certbot_output" | grep -oP 'Key is saved at: \K.*')
    echo "Certificate is saved at: $fullchain_path"
    echo "Key is saved at: $privkey_path"
    echo "Please update your nginx configuration file with these paths and then run 'nginx -s reload'."
else
    echo "Could not find the certificate path in the output, please check the log file."
fi

