#!/bin/sh
HOST_NAME=
CERT_NAME=$(jq -r 'to_entries[] | select(.value.user_deletable == true and (.value.services[]? | .display_name_i18n == "common:web_desktop")) | .key' /usr/syno/etc/certificate/_archive/INFO)

if [ -z "$HOST_NAME" ]; then
    echo "Error: HOST_NAME env variable not set in .env file."
    exit 1
fi

if [ -z "$CERT_NAME" ]; then
    echo "Error: No user defined cert found for replacement."
    exit 1
fi

echo "Certificate for $CERT_NAME found... Running certbot"
docker run --rm \
  --name certbot-dns \
  --dns 1.1.1.1 \
  --dns 1.0.0.1 \
  -e HOST_NAME="$HOST_NAME" \
  -v ./cloudflare.ini:/cloudflare.ini:ro \
  -v ./conf:/etc/letsencrypt \
  -v ./logs:/var/log/letsencrypt \
  certbot/dns-cloudflare:latest \
  certonly -d "$HOST_NAME" \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  --email "admin@$HOST_NAME" \
  --agree-tos \
  --non-interactive

if [ ! -f "conf/live/$HOST_NAME/privkey.pem" ]; then
    echo "Error: No certbot certificate found in ./conf/live/$HOST_NAME/ to update $CERT_NAME"
    exit 1
fi

if ! cmp -s "conf/live/$HOST_NAME/privkey.pem" "/usr/syno/etc/certificate/_archive/$CERT_NAME/privkey.pem"; then
    # Copy certificate
    echo "New certbot certificate found... Copying to /usr/syno/etc/certificate/_archive/$CERT_NAME/"
    cp conf/live/$HOST_NAME/* /usr/syno/etc/certificate/_archive/$CERT_NAME/

    # Restart synology services
    echo -n "Restarting..."
    /usr/syno/bin/synosystemctl restart nginx
    echo " done"
else
    # No difference
    echo "No certificate change"
fi
