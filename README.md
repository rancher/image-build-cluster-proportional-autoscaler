# image-build-cluster-proportional-autoscaler

This repo builds hardened, statically-linked Go binaries from the
[kubernetes-sigs/cluster-proportional-autoscaler](github.com/kubernetes-sigs/cluster-proportional-autoscaler) repo, which is published upstream at `registry.k8s.io/cpa/cluster-proportional-autoscaler`.

Our resulting image is published at [rancher/hardened-cluster-autoscalar](https://hub.docker.com/r/rancher/hardened-cluster-autoscaler).