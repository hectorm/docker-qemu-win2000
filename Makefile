#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -eu -c

DOCKER := $(shell command -v docker 2>/dev/null)
GIT := $(shell command -v git 2>/dev/null)
M4 := $(shell command -v m4 2>/dev/null)

DISTDIR := ./dist
VERSION_FILE = ./VERSION
DOCKERFILE_TEMPLATE := ./Dockerfile.m4

IMAGE_REGISTRY := docker.io
IMAGE_NAMESPACE := hectormolinero
IMAGE_PROJECT := qemu-win2000
IMAGE_NAME := $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_PROJECT)

IMAGE_VERSION := v0
ifneq ($(wildcard $(VERSION_FILE)),)
	IMAGE_VERSION := $(shell cat '$(VERSION_FILE)')
endif

IMAGE_BUILD_OPTS :=

IMAGE_NATIVE_DOCKERFILE := $(DISTDIR)/Dockerfile
IMAGE_NATIVE_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).tzst

IMAGE_AMD64_DOCKERFILE := $(DISTDIR)/Dockerfile.amd64
IMAGE_AMD64_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).amd64.tzst

IMAGE_ARM64V8_DOCKERFILE := $(DISTDIR)/Dockerfile.arm64v8
IMAGE_ARM64V8_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm64v8.tzst

IMAGE_ARM32V7_DOCKERFILE := $(DISTDIR)/Dockerfile.arm32v7
IMAGE_ARM32V7_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm32v7.tzst

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
		'$(DOCKERFILE_TEMPLATE)' | cat --squeeze-blank > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)' \
		--tag '$(IMAGE_NAME):latest' \
		--file '$@' ./

.PHONY: build-cross-images
build-cross-images: build-amd64-image build-arm64v8-image build-arm32v7-image

.PHONY: build-amd64-image
build-amd64-image: $(IMAGE_AMD64_DOCKERFILE)

$(IMAGE_AMD64_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		-D CROSS_ARCH=amd64 \
		-D CROSS_QEMU=/usr/bin/qemu-x86_64-static \
		'$(DOCKERFILE_TEMPLATE)' | cat --squeeze-blank > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-amd64' \
		--tag '$(IMAGE_NAME):latest-amd64' \
		--file '$@' ./

.PHONY: build-arm64v8-image
build-arm64v8-image: $(IMAGE_ARM64V8_DOCKERFILE)

$(IMAGE_ARM64V8_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		-D CROSS_ARCH=arm64v8 \
		-D CROSS_QEMU=/usr/bin/qemu-aarch64-static \
		'$(DOCKERFILE_TEMPLATE)' | cat --squeeze-blank > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8' \
		--tag '$(IMAGE_NAME):latest-arm64v8' \
		--file '$@' ./

.PHONY: build-arm32v7-image
build-arm32v7-image: $(IMAGE_ARM32V7_DOCKERFILE)

$(IMAGE_ARM32V7_DOCKERFILE): $(DOCKERFILE_TEMPLATE)
	mkdir -p '$(DISTDIR)'
	'$(M4)' \
		--prefix-builtins \
		-D CROSS_ARCH=arm32v7 \
		-D CROSS_QEMU=/usr/bin/qemu-arm-static \
		'$(DOCKERFILE_TEMPLATE)' | cat --squeeze-blank > '$@'
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7' \
		--tag '$(IMAGE_NAME):latest-arm32v7' \
		--file '$@' ./

##################################################
## "save-*" targets
##################################################

define save_image
	'$(DOCKER)' save '$(1)' | zstd -T0 -19 > '$(2)'
endef

.PHONY: save-native-image
save-native-image: $(IMAGE_NATIVE_TARBALL)

$(IMAGE_NATIVE_TARBALL): $(IMAGE_NATIVE_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION),$@)

.PHONY: save-cross-images
save-cross-images: save-amd64-image save-arm64v8-image save-arm32v7-image

.PHONY: save-amd64-image
save-amd64-image: $(IMAGE_AMD64_TARBALL)

$(IMAGE_AMD64_TARBALL): $(IMAGE_AMD64_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$@)

.PHONY: save-arm64v8-image
save-arm64v8-image: $(IMAGE_ARM64V8_TARBALL)

$(IMAGE_ARM64V8_TARBALL): $(IMAGE_ARM64V8_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$@)

.PHONY: save-arm32v7-image
save-arm32v7-image: $(IMAGE_ARM32V7_TARBALL)

$(IMAGE_ARM32V7_TARBALL): $(IMAGE_ARM32V7_DOCKERFILE)
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$@)

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
load-cross-images: load-amd64-image load-arm64v8-image load-arm32v7-image

.PHONY: load-amd64-image
load-amd64-image:
	$(call load_image,$(IMAGE_AMD64_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$(IMAGE_NAME):latest-amd64)

.PHONY: load-arm64v8-image
load-arm64v8-image:
	$(call load_image,$(IMAGE_ARM64V8_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$(IMAGE_NAME):latest-arm64v8)

.PHONY: load-arm32v7-image
load-arm32v7-image:
	$(call load_image,$(IMAGE_ARM32V7_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$(IMAGE_NAME):latest-arm32v7)

##################################################
## "push-*" targets
##################################################

define push_image
	'$(DOCKER)' push '$(1)'
endef

define push_cross_manifest
	'$(DOCKER)' manifest create --amend '$(1)' '$(2)-amd64' '$(2)-arm64v8' '$(2)-arm32v7'
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-amd64' --os linux --arch amd64
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm64v8' --os linux --arch arm64 --variant v8
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm32v7' --os linux --arch arm --variant v7
	'$(DOCKER)' manifest push --purge '$(1)'
endef

.PHONY: push-native-image
push-native-image:
	@printf '%s\n' 'Unimplemented'

.PHONY: push-cross-images
push-cross-images: push-amd64-image push-arm64v8-image push-arm32v7-image

.PHONY: push-amd64-image
push-amd64-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64)
	$(call push_image,$(IMAGE_NAME):latest-amd64)

.PHONY: push-arm64v8-image
push-arm64v8-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8)
	$(call push_image,$(IMAGE_NAME):latest-arm64v8)

.PHONY: push-arm32v7-image
push-arm32v7-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7)
	$(call push_image,$(IMAGE_NAME):latest-arm32v7)

push-cross-manifest:
	$(call push_cross_manifest,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):$(IMAGE_VERSION))
	$(call push_cross_manifest,$(IMAGE_NAME):latest,$(IMAGE_NAME):latest)

##################################################
## "binfmt-*" targets
##################################################

.PHONY: binfmt-register
binfmt-register:
	'$(DOCKER)' run --rm --privileged docker.io/hectormolinero/qemu-user-static:latest --reset

##################################################
## "version" target
##################################################

.PHONY: version
version:
	@if printf '%s' '$(IMAGE_VERSION)' | grep -q '^v[0-9]\{1,\}$$'; then \
		NEW_IMAGE_VERSION=$$(awk -v 'v=$(IMAGE_VERSION)' 'BEGIN {printf "v%.0f", substr(v,2)+1}'); \
		printf '%s\n' "$${NEW_IMAGE_VERSION:?}" > '$(VERSION_FILE)'; \
		'$(GIT)' add '$(VERSION_FILE)'; '$(GIT)' commit -m "$${NEW_IMAGE_VERSION:?}"; \
		'$(GIT)' tag -a "$${NEW_IMAGE_VERSION:?}" -m "$${NEW_IMAGE_VERSION:?}"; \
	else \
		>&2 printf 'Malformed version string: %s\n' '$(IMAGE_VERSION)'; \
		exit 1; \
	fi

##################################################
## "clean" target
##################################################

.PHONY: clean
clean:
	rm -f '$(IMAGE_NATIVE_DOCKERFILE)' '$(IMAGE_AMD64_DOCKERFILE)' '$(IMAGE_ARM64V8_DOCKERFILE)' '$(IMAGE_ARM32V7_DOCKERFILE)'
	rm -f '$(IMAGE_NATIVE_TARBALL)' '$(IMAGE_AMD64_TARBALL)' '$(IMAGE_ARM64V8_TARBALL)' '$(IMAGE_ARM32V7_TARBALL)'
	if [ -d '$(DISTDIR)' ] && [ -z "$$(ls -A '$(DISTDIR)')" ]; then rmdir '$(DISTDIR)'; fi
