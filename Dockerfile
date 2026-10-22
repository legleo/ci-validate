# CI image of the GitOps repos of the unys cluster (unys-k8s on GitHub Actions, entrelasque on
# Forgejo Actions): the tools used by validate.sh and the workflows, installed once here instead
# of at every run. Tools only: the validation scripts are not here, each repo takes them from its
# own (private) submodule, at the commit it pins.
#
# node: the JavaScript actions (actions/checkout, node24 since v5) run with the node of the job
# container on Forgejo. Debian (glibc) rather than Alpine: GitHub mounts its own node into the
# container, which needs glibc.
FROM docker.io/library/node:24.22.1-trixie-slim@sha256:43b9ba1142b8dcf33fa8f922ca1be85714adc444e0586c7cf7726daaeabc1bea

# Kubernetes version of the cluster: kubectl (kubectl kustomize), and the schemas of kubeconform
# and flate. Updated by hand, with the cluster
ARG KUBE_VERSION=1.36.0
# renovate: datasource=github-releases depName=home-operations/flate extractVersion=^v(?<version>.+)$
ARG FLATE_VERSION=0.6.5
# renovate: datasource=github-releases depName=yannh/kubeconform extractVersion=^v(?<version>.+)$
ARG KUBECONFORM_VERSION=0.8.0
# renovate: datasource=github-releases depName=FairwindsOps/pluto extractVersion=^v(?<version>.+)$
ARG PLUTO_VERSION=5.24.4
# renovate: datasource=github-releases depName=gitleaks/gitleaks extractVersion=^v(?<version>.+)$
ARG GITLEAKS_VERSION=8.30.1
# promtool, for the alert rule tests of unys-k8s
# renovate: datasource=github-releases depName=prometheus/prometheus extractVersion=^v(?<version>.+)$
ARG PROMETHEUS_VERSION=3.12.0
# gh: the PR comment of the flate diff on GitHub (not preinstalled in a job container)
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.+)$
ARG GH_VERSION=2.103.0

# python3-yaml: check.py and validate.sh. git: checkout, gitleaks, validate.sh. curl: the PR
# comment through the Forgejo API
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git python3 python3-yaml \
 && rm -rf /var/lib/apt/lists/*

# Every binary is checked against the checksums published with its release (for kubectl and
# flate, the .sha256 file only holds the hash)
# get: release-url archive checksums-file binary [leading directories to strip]
RUN set -eu; \
    get() { \
      cd "$(mktemp -d)"; \
      curl -sSfL "$1/$2" -o "$2"; \
      curl -sSfL "$1/$3" -o checksums; \
      grep "  $2\$" checksums | sha256sum -c -; \
      tar -xzf "$2" -C /usr/local/bin --strip-components="${5:-0}" "$4"; \
    }; \
    get "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}" \
      kubeconform-linux-amd64.tar.gz CHECKSUMS kubeconform; \
    get "https://github.com/FairwindsOps/pluto/releases/download/v${PLUTO_VERSION}" \
      "pluto_${PLUTO_VERSION}_linux_amd64.tar.gz" checksums.txt pluto; \
    get "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}" \
      "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" "gitleaks_${GITLEAKS_VERSION}_checksums.txt" gitleaks; \
    get "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}" \
      "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" sha256sums.txt \
      "prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool" 1; \
    get "https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
      "gh_${GH_VERSION}_linux_amd64.tar.gz" "gh_${GH_VERSION}_checksums.txt" \
      "gh_${GH_VERSION}_linux_amd64/bin/gh" 2; \
    cd "$(mktemp -d)"; \
    curl -sSfL "https://dl.k8s.io/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl" -o kubectl; \
    echo "$(curl -sSfL "https://dl.k8s.io/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl.sha256")  kubectl" | sha256sum -c -; \
    install -m 0755 kubectl /usr/local/bin/kubectl; \
    url="https://github.com/home-operations/flate/releases/download/v${FLATE_VERSION}/flate_${FLATE_VERSION}_linux_amd64.tar.gz"; \
    curl -sSfL "$url" -o flate.tar.gz; \
    echo "$(curl -sSfL "$url.sha256")  flate.tar.gz" | sha256sum -c -; \
    tar -xzf flate.tar.gz -C /usr/local/bin flate; \
    rm -rf /tmp/*

# Fails the build if a tool is missing or does not run
RUN kubectl version --client && kubeconform -v && pluto version && gitleaks version \
 && promtool --version && gh --version && flate --help >/dev/null && python3 -c 'import yaml'
