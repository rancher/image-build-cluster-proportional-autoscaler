ARG GO_IMAGE=rancher/hardened-build-base:v1.25.14b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
COPY --from=xx / /
# setup required packages
RUN set -x && \
    apk --no-cache add \
    file \
    gcc \
    git \
    make \
    clang lld

# setup the autoscaler build
FROM base-builder AS autoscaler-builder
ARG PKG=github.com/kubernetes-sigs/cluster-proportional-autoscaler
RUN git clone --depth=1 https://${PKG}.git $GOPATH/src/${PKG}
ARG TAG=v1.10.3
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}

ARG TARGETPLATFORM
RUN set -x && \
    xx-apk add musl-dev gcc  lld 

COPY go-mod-overrides ./go-mod-overrides
RUN go-mod-overrides.sh ./go-mod-overrides

ARG TARGETARCH
RUN xx-go --wrap && \
    GO_LDFLAGS="-linkmode=external -X ${PKG}/pkg/version.VERSION=${TAG}" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o . ./...
RUN go-assert-static.sh cluster-proportional-autoscaler
RUN if [ `xx-info arch` = "amd64" ]; then \
    	go-assert-boring.sh cluster-proportional-autoscaler; \
    fi
RUN install cluster-proportional-autoscaler /usr/local/bin

#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
FROM ${GO_IMAGE} AS strip_binary
COPY --from=autoscaler-builder /usr/local/bin/cluster-proportional-autoscaler /cluster-proportional-autoscaler
RUN strip /cluster-proportional-autoscaler

FROM scratch AS autoscaler
COPY --from=strip_binary /cluster-proportional-autoscaler /cluster-proportional-autoscaler
ENTRYPOINT ["/cluster-proportional-autoscaler"]
