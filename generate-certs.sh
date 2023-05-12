#!/bin/bash

# Copy the CA Config to the container
echo "Copying the CA Config to the step-ca container..."
docker exec -i step-ca mkdir -p /home/step/config
docker cp ./step-ca/ca-config.json step-ca:/home/step/config/ca.json

# Restart the step-ca container to load the new config
echo "Restarting the step-ca container to load the new config..."
docker-compose restart step-ca

# Wait for the step-ca container to be ready
until docker-compose exec -T step-ca nc -z localhost 9000 > /dev/null 2>&1; do
    echo "Waiting for step-ca container to be ready..."
    sleep 5
done

# Get the fingerprint
echo "Getting the fingerprint from the step-ca container..."
CA_FINGERPRINT=$(docker-compose exec -T step-ca step certificate fingerprint /home/step/certs/root_ca.crt)

# Bootstrap the CA
echo "Bootstrapping the CA..."
step_ca_container_id=$(docker-compose ps -q step-ca)
docker exec -i $step_ca_container_id step ca bootstrap --ca-url https://localhost:9000 --fingerprint $CA_FINGERPRINT --install --force 2> /dev/null

# Create the certificate for the localtest.me domain
echo "Creating the certificate for the localtest.me domain..."
cert_gen_cmd=("step" "ca" "certificate" "*.localtest.me" "/certs/localtest.me.crt" "/certs/localtest.me.key" "--san=*.localtest.me" "--not-after" "8760h" "--provisioner=admin" "--password-file=/home/step/secrets/password" "--force")
docker-compose exec -T step-ca "${cert_gen_cmd[@]}"

# This will execute:
docker-compose exec -T step-ca step ca certificate "*.localtest.me" "/certs/localtest.me.crt" "/certs/localtest.me.key" --san="*.localtest.me" --not-after 8760h --provisioner=admin --password-file=/home/step/secrets/password --force

# Export the root CA certificate
echo "Exporting the root CA certificate..."
docker-compose exec -T step-ca step certificate bundle /home/step/certs/root_ca.crt /home/step/certs/root_ca.crt ./root_ca.crt --force

# Copy the root CA certificate to the host
echo "Copying the root CA certificate to the host..."
docker cp step-ca:/home/step/certs/root_ca.crt ./certs/

# Restart the traefik container to load the new certificates
echo "Restarting the traefik container to load the new certificates..."
docker-compose restart proxy

# Create certificate chain for the localtest.me domain
echo "Creating certificate chain for the localtest.me domain..."
cat ./certs/localtest.me.crt ./certs/root_ca.crt > ./certs/localtest.me.chain.crt

# Create the P12 bundle for the localtest.me domain
echo "Creating a bundle for the localtest.me domain..."
openssl pkcs12 -export -in certs/localtest.me.chain.crt -inkey certs/localtest.me.key -name ignition -passout pass:ignition -out certs/localtest.me.p12

# Convert the PKCS12 bundle to JKS format for the localtest.me domain
echo "Converting the PKCS12 bundle to JKS format..."
keytool -importkeystore -noprompt -srckeystore certs/localtest.me.p12 -srcstoretype pkcs12 -srcalias ignition -destkeystore certs/localtest.me.jks -deststoretype jks -destalias ignition -storepass ignition -srcstorepass "ignition" > /dev/null 2>&1

echo "Certificates generated successfully."