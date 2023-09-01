# Traefik Proxy

___

## Setup

1. Clone this repository locally.

    ```sh
    git clone https://github.com/design-group/traefik-proxy.git traefik-proxy && cd traefik-proxy
    ```

2. Pull any changes to the docker image and start the container.
      
    On Mac:
    
	```sh
    docker compose pull && docker compose up -d
    ```
    
	On Windows WSL or Linux:
    
	```sh
    docker-compose pull && docker-compose up -d
    ```

Once the Traefik container is running, its web page should be accessible at `proxy.localtest.me`. This URL is configurable in the Traefik `docker-compose.yml` file using the `traefik.http.routers.proxy.rule` label.
___

## Usage

To add an Ignition Gateway or other container to the proxy, add the following labels and environment variables to the container:

```yaml
labels:
  traefik.enable: "true"
  traefik.http.routers.<container-name>.entrypoints: "web"
  traefik.http.routers.<container-name>.rule: "Host(`<container-name>.localtest.me`)"
  traefik.http.services.<container-name>.loadbalancer.server.port: "<container-port>"
environment:
  GATEWAY_SYSTEM_NAME: <container-name>
  GATEWAY_PUBLIC_HTTP_PORT: 80
  GATEWAY_PUBLIC_HTTPS_PORT: 443
  GATEWAY_PUBLIC_ADDRESS: <container-name>.localtest.me
```

For example, to add an Ignition Gateway to the proxy, add the following labels and environment variables to the container:

```yaml
labels:
  traefik.enable: "true"
  traefik.http.routers.ignition.entrypoints: "web"
  traefik.http.routers.ignition.rule: "Host(`ignition.localtest.me`)"
  traefik.http.services.ignition.loadbalancer.server.port: "8088"
environment:
  GATEWAY_SYSTEM_NAME: ignition
  GATEWAY_PUBLIC_HTTP_PORT: 80
  GATEWAY_PUBLIC_HTTPS_PORT: 443
  GATEWAY_PUBLIC_ADDRESS: ignition.localtest.me
```

The traefik proxy is configured to use the `proxy` network. If the container is not on the `proxy` network, add the following to the container:

```yaml
networks:
  - default
  - proxy
```

Then add the following to the `docker-compose.yml` file:

```yaml
networks:
    default:
    proxy:
        external: true
        name: proxy
```

After adding the labels and environment variables, restart the container. Once the container restarts, it should be accessible at `http://<container-name>.localtest.me/`.

___

## Projects with Pre-Existing docker-compose.yml Files

If the project already has a `docker-compose.yml` file, you can add a file named `docker-compose.traefik.yml` to the project. This file will be used to add the labels and environment variables to the container. In order to get your local environment to use this file, add the following to the `.env` file:

```sh
COMPOSE_PATH_SEPARATOR=:
COMPOSE_FILE=docker-compose.yml:docker-compose.traefik.yml
```

Then, add the labels and environment variables to the `docker-compose.traefik.yml` file. For example, here is the pre-existing `docker-compose.yml` file for the Ignition Gateway:

```yaml
services:
  ignition:
    image: bwdesigngroup/ignition-docker:8.1.22
    ports:
      - 8088:8088
    volumes:
      - ignition-data:/workdir
```

Here is the `docker-compose.traefik.yml` file for the Ignition Gateway:

```yaml
services:
  ignition:
    labels:
      traefik.enable: "true"
      traefik.http.routers.ignition.entrypoints: "web"
      traefik.http.routers.ignition.rule: "Host(`ignition.localtest.me`)"
      traefik.http.services.ignition.loadbalancer.server.port: "8088"
    environment:
      GATEWAY_SYSTEM_NAME: ignition
      GATEWAY_PUBLIC_HTTP_PORT: 80
      GATEWAY_PUBLIC_HTTPS_PORT: 443
      GATEWAY_PUBLIC_ADDRESS: ignition.localtest.me
    networks:
      - default
      - proxy

networks:
  default:
  proxy:
    external: true
    name: proxy
```

After adding the labels and environment variables, re-up the container. Once the container restarts, it should be accessible at `http://ignition.localtest.me/` (assuming that the Traefix container is currently running).

```sh
docker-compose up -d
```

___

## Troubleshooting

### Gateway is Not Accessible

If the Gateway is not accessible, check the following:

1. Is the Gateway container running?
2. Is the Gateway container using the correct labels?
3. Is the Gateway container using the correct port?
4. Is the Gateway container using the correct hostname?
5. Is the Gateway container using the correct IP address?
6. Is the Gateway container using the correct network?

### Error When Up-ing the Container
If you receive a "network proxy declared as external, but could not be found" error, make sure the the Traefik container is running (it may be using a separate `docker-compose.yml` file that needs to be up'ed separately. Alternatively, try running `docker network create proxy` to create the proxy network manually.
