DOCKER_REPO ?= hub.docker.com/
TAG ?= 2.0-d1
KONG_OIDC_VERSION ?= 1.1.0-1

.PHONY: clean kong_image kong_push help

.DEFAULT_GOAL := help

## clean
clean:
	rm -rf ./rocksdir

## build_kong_oidc_rock
build_kong_oidc_rock: clean
	./build_kong_oidc_rock.sh

## kong_image
kong_image: build_kong_oidc_rock
	 docker build \
   --build-arg KONG_BASE="kong:2.0.4" \
   --build-arg PLUGINS="/rocks-server/kong-oidc-$(KONG_OIDC_VERSION).all.rock,/rocks-server/lua-resty-openidc-1.6.1-1.all.rock" \
	 --build-arg ROCKS_DIR="./rocksdir" \
   --tag "rubiklabs/kong:$(TAG)" .

## kong_push
kong_push: kong_image
	docker push "rubiklabs/kong:$(TAG)"

help : Makefile
	@sed -n 's/^##//p' $<
