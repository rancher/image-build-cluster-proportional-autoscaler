SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

BUILD_META=-build$(shell date +%Y%m%d)
TAG ?= ${GITHUB_ACTION_TAG}
REPO ?= rancher
IMAGE ?= $(REPO)/hardened-cluster-autoscaler:$(TAG)

export DOCKER_BUILDKIT?=1

ifeq ($(TAG),)
TAG := $(shell cat TAG)$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker buildx build \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target autoscaler \
		--tag $(IMAGE) \
		--load \
	.

.PHONY: push-image
push-image:
	docker buildx build \
		$(IID_FILE_FLAG) \
		$(BUILDX_ARGS) \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(IMAGE) \
		--push \
		.

.PHONY: push-prime-image
push-prime-image:
	BUILDX_ARGS="--sbom=true --attest type=provenance,mode=max" \
	$(MAKE) push-image

.PHONY: image-push
image-push:
	docker push $(IMAGE)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(IMAGE) \
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(IMAGE)

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(IMAGE)

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
