VERSION ?= 1.6.16
SUFFIX ?= re6

REGISTRY ?= cr.v.zyxmasta.net
REPOSITORY ?= utils
PROJECT ?= roundcubemail
PLATFORM ?= linux/amd64,linux/arm64

TAG ?= $(VERSION)-$(SUFFIX)
BUILD_DATETIME = $(shell date -u +"%FT%T")
REV_ID := $(shell git describe --match=none --always --abbrev=8 --dirty)

IMAGE := $(REGISTRY)/$(REPOSITORY)/$(PROJECT):$(TAG)

BUILD_ARGS = --build-arg BUILD_DATE=$(BUILD_DATETIME)
BUILD_ARGS += --build-arg BUILD_VERSION=$(TAG)
BUILD_ARGS += --build-arg APP_VERSION=$(VERSION)
BUILD_ARGS += --build-arg BUILD_REVISION=$(REV_ID)

build:
	@echo "IMAGE: $(IMAGE)"
	@docker buildx build -D -t $(IMAGE) --platform $(PLATFORM) --push $(BUILD_ARGS) .

purge:
	rm -rf x/config/* x/config/.migrations x/data/*
