VERSION ?= 1.6.16
SUFFIX ?= re4

REGISTRY ?= cr.v.zyxmasta.net
REPOSITORY ?= utils
PROJECT ?= roundcubemail
PLATFORM ?= linux/amd64,linux/arm64

TAG ?= $(VERSION)-$(SUFFIX)
BUILD_DATETIME = $(shell date -u +"%FT%T")

IMAGE := $(REGISTRY)/$(REPOSITORY)/$(PROJECT):$(TAG)

BUILD_ARGS = --build-arg BUILD_DATE=$(BUILD_DATETIME)
BUILD_ARGS += --build-arg BUILD_VERSION=$(TAG)
BUILD_ARGS += --build-arg ROUNDCUBEMAIL_VERSION=$(VERSION)
BUILD_ARGS += --build-arg BUILD_REV_ID=1234

build:
	@echo "IMAGE: $(IMAGE)"
	@docker buildx build -D -t $(IMAGE) --platform $(PLATFORM) --push $(BUILD_ARGS) .

purge:
	rm -rf x/config/* x/config/.migrations x/data/*
