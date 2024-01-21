#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -euc

DOCKER := $(shell command -v docker 2>/dev/null)
GIT := $(shell command -v git 2>/dev/null)
M4 := $(shell command -v m4 2>/dev/null)

DISTDIR := ./dist
DOCKERFILE_TEMPLATE := ./Dockerfile.m4

IMAGE_REGISTRY := docker.io
IMAGE_NAMESPACE := hectorm
IMAGE_PROJECT := qemu-win2000
IMAGE_NAME := $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_PROJECT)
ifeq ($(shell '$(GIT)' status --porcelain 2>/dev/null),)
	IMAGE_GIT_TAG := $(shell '$(GIT)' tag --list --contains HEAD 2>/dev/null)
	IMAGE_GIT_SHA := $(shell '$(GIT)' rev-parse --verify --short HEAD 2>/dev/null)
	IMAGE_VERSION := $(if $(IMAGE_GIT_TAG),$(IMAGE_GIT_TAG),$(if $(IMAGE_GIT_SHA),$(IMAGE_GIT_SHA),nil))
else
	IMAGE_GIT_BRANCH := $(shell '$(GIT)' symbolic-ref --short HEAD 2>/dev/null)
	IMAGE_VERSION := $(if $(IMAGE_GIT_BRANCH),$(IMAGE_GIT_BRANCH)-dirty,nil)
endif

IMAGE_BUILD_OPTS :=

IMAGE_NATIVE_DOCKERFILE := $(DISTDIR)/Dockerfile
IMAGE_NATIVE_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).tzst
IMAGE_AMD64_DOCKERFILE := $(DISTDIR)/Dockerfile.amd64
IMAGE_AMD64_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).amd64.tzst
IMAGE_ARM64V8_DOCKERFILE := $(DISTDIR)/Dockerfile.arm64v8
IMAGE_ARM64V8_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm64v8.tzst

export DOCKER_BUILDKIT := 1
export BUILDKIT_PROGRESS := plain

##################################################
## "all" target
##################################################

.PHONY: all
all: save-native-image

##################################################
## "build-*" targets
##################################################

.PHONY: build-native-image
build-native-image: $(IMAGE_NATIVE_DOCKERFILE)

$(IMAGE_NATIVE_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		'$(DOCKERFILE_TEMPLATE)' > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)' \
		--tag '$(IMAGE_NAME):latest' \
		--file '$@' ./

.PHONY: build-cross-images
build-cross-images: build-amd64-image build-arm64v8-image

.PHONY: build-amd64-image
build-amd64-image: $(IMAGE_AMD64_DOCKERFILE)

$(IMAGE_AMD64_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		--define=CROSS_ARCH=amd64 \
		--define=CROSS_QEMU=/usr/bin/qemu-x86_64-static \
		'$(DOCKERFILE_TEMPLATE)' > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-amd64' \
		--tag '$(IMAGE_NAME):latest-amd64' \
		--platform linux/amd64 \
		--file '$@' ./

.PHONY: build-arm64v8-image
build-arm64v8-image: $(IMAGE_ARM64V8_DOCKERFILE)

$(IMAGE_ARM64V8_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		--define=CROSS_ARCH=arm64v8 \
		--define=CROSS_QEMU=/usr/bin/qemu-aarch64-static \
		'$(DOCKERFILE_TEMPLATE)' > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8' \
		--tag '$(IMAGE_NAME):latest-arm64v8' \
		--platform linux/arm64/v8 \
		--file '$@' ./

##################################################
## "save-*" targets
##################################################

define save_image
	'$(DOCKER)' save '$(1)' | zstd -T0 > '$(2)'
endef

.PHONY: save-native-image
save-native-image: $(IMAGE_NATIVE_TARBALL)

$(IMAGE_NATIVE_TARBALL): $(IMAGE_NATIVE_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION),$@)

.PHONY: save-cross-images
save-cross-images: save-amd64-image save-arm64v8-image

.PHONY: save-amd64-image
save-amd64-image: $(IMAGE_AMD64_TARBALL)

$(IMAGE_AMD64_TARBALL): $(IMAGE_AMD64_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$@)

.PHONY: save-arm64v8-image
save-arm64v8-image: $(IMAGE_ARM64V8_TARBALL)

$(IMAGE_ARM64V8_TARBALL): $(IMAGE_ARM64V8_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$@)

##################################################
## "load-*" targets
##################################################

define load_image
	zstd -dc '$(1)' | '$(DOCKER)' load
endef

define tag_image
	'$(DOCKER)' tag '$(1)' '$(2)'
endef

.PHONY: load-native-image
load-native-image:
	$(call load_image,$(IMAGE_NATIVE_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):latest)

.PHONY: load-cross-images
load-cross-images: load-amd64-image load-arm64v8-image

.PHONY: load-amd64-image
load-amd64-image:
	$(call load_image,$(IMAGE_AMD64_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$(IMAGE_NAME):latest-amd64)

.PHONY: load-arm64v8-image
load-arm64v8-image:
	$(call load_image,$(IMAGE_ARM64V8_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$(IMAGE_NAME):latest-arm64v8)

##################################################
## "push-*" targets
##################################################

define push_image
	'$(DOCKER)' push '$(1)'
endef

define push_cross_manifest
	'$(DOCKER)' manifest create --amend '$(1)' '$(2)-amd64' '$(2)-arm64v8'
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-amd64' --os linux --arch amd64
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm64v8' --os linux --arch arm64 --variant v8
	'$(DOCKER)' manifest push --purge '$(1)'
endef

.PHONY: push-native-image
push-native-image:
	@printf '%s\n' 'Unimplemented'

.PHONY: push-cross-images
push-cross-images: push-amd64-image push-arm64v8-image

.PHONY: push-amd64-image
push-amd64-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64)
	$(call push_image,$(IMAGE_NAME):latest-amd64)

.PHONY: push-arm64v8-image
push-arm64v8-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8)
	$(call push_image,$(IMAGE_NAME):latest-arm64v8)

push-cross-manifest:
	$(call push_cross_manifest,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):$(IMAGE_VERSION))
	$(call push_cross_manifest,$(IMAGE_NAME):latest,$(IMAGE_NAME):latest)

##################################################
## "binfmt-*" targets
##################################################

.PHONY: binfmt-register
binfmt-register:
	'$(DOCKER)' run --rm --privileged docker.io/hectorm/qemu-user-static:latest --reset --persistent yes

##################################################
## "version" target
##################################################

.PHONY: version
version:
	@LATEST_IMAGE_VERSION=$$('$(GIT)' describe --abbrev=0 2>/dev/null || printf 'v0'); \
	if printf '%s' "$${LATEST_IMAGE_VERSION:?}" | grep -q '^v[0-9]\{1,\}$$'; then \
		NEW_IMAGE_VERSION=$$(awk -v v="$${LATEST_IMAGE_VERSION:?}" 'BEGIN {printf("v%.0f", substr(v,2)+1)}'); \
		'$(GIT)' commit --allow-empty -m "$${NEW_IMAGE_VERSION:?}"; \
		'$(GIT)' tag -a "$${NEW_IMAGE_VERSION:?}" -m "$${NEW_IMAGE_VERSION:?}"; \
	else \
		>&2 printf 'Malformed version string: %s\n' "$${LATEST_IMAGE_VERSION:?}"; \
		exit 1; \
	fi

##################################################
## "clean" target
##################################################

.PHONY: clean
clean:
	rm -f '$(IMAGE_NATIVE_DOCKERFILE)' '$(IMAGE_AMD64_DOCKERFILE)' '$(IMAGE_ARM64V8_DOCKERFILE)'
	rm -f '$(IMAGE_NATIVE_TARBALL)' '$(IMAGE_AMD64_TARBALL)' '$(IMAGE_ARM64V8_TARBALL)'
	if [ -d '$(DISTDIR)' ] && [ -z "$$(ls -A '$(DISTDIR)')" ]; then rmdir '$(DISTDIR)'; fi
