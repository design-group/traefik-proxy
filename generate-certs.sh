#!/bin/bash

# Wait for the step-ca container to be ready
until docker-compose exec -T step-ca nc -z localhost 9000 > /dev/null 2>&1; do
    echo "Waiting for step-ca container to be ready..."
    sleep 5
done

# Get the password from the container
PASSWORD=$(docker-compose logs step-ca | awk -F': ' '/Your CA administrative password is/ {print $2}')

# Get the fingerprint
CA_FINGERPRINT=$(docker-compose exec -T step-ca step certificate fingerprint /home/step/certs/root_ca.crt)

# Bootstrap the CA
step_ca_container_id=$(docker-compose ps -q step-ca)
docker exec -i $step_ca_container_id step ca bootstrap --ca-url https://localhost:9000 --fingerprint $CA_FINGERPRINT --install --force 2> /dev/null

# Create the certificate for the localtest.me domain
cert_gen_cmd=("step" "ca" "certificate" "*.localtest.me" "/certs/localtest.me.crt" "/certs/localtest.me.key" "--san=*.localtest.me" "--not-after" "24h" "--provisioner=admin" "--password-file=/dev/stdin" "--force")
echo "$PASSWORD" | docker exec -i $step_ca_container_id "${cert_gen_cmd[@]}"

# Export the root CA certificate
docker-compose exec -T step-ca step certificate bundle /home/step/certs/root_ca.crt /home/step/certs/root_ca.crt ./root_ca.crt --force

# Copy the root CA certificate to the host
docker cp step-ca:/home/step/certs/root_ca.crt ./

# Restart the traefik container to load the new certificates
docker-compose restart proxy

echo "Certificates generated successfully."