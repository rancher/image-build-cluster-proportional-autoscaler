ARG GO_IMAGE=rancher/hardened-build-base:v1.22.0b1
FROM ${GO_IMAGE} as base-builder
# setup required packages
RUN set -x && \
    apk --no-cache add \
    file \
    gcc \
    git \
    make

# setup the autoscaler build
FROM base-builder as autoscaler-builder
ARG SRC=github.com/kubernetes-sigs/cluster-proportional-autoscaler
ARG PKG=github.com/kubernetes-sigs/cluster-proportional-autoscaler
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
ARG TAG=1.8.10
ARG ARCH="amd64"
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN GOARCH=${ARCH} GO_LDFLAGS="-linkmode=external -X ${PKG}/pkg/version.VERSION=${TAG}" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o . ./...
RUN go-assert-static.sh cluster-proportional-autoscaler
RUN if [ "${ARCH}" = "amd64" ]; then \
    	go-assert-boring.sh cluster-proportional-autoscaler; \
    fi
RUN install -s cluster-proportional-autoscaler /usr/local/bin

FROM scratch as autoscaler
COPY --from=autoscaler-builder /usr/local/bin/cluster-proportional-autoscaler /cluster-proportional-autoscaler
ENTRYPOINT ["/cluster-proportional-autoscaler"]
