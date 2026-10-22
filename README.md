# ci-validate

CI image of the GitOps repos of the `unys` home Kubernetes cluster: the tools their validation
runs, installed once here instead of at every CI run.

| Tool | Used for |
|---|---|
| `kubectl` | `kubectl kustomize`, at the Kubernetes version of the cluster |
| `kubeconform` | Kubernetes schema validation |
| `pluto` | removed and deprecated APIs |
| `gitleaks` | secrets in the git history |
| [`flate`](https://github.com/home-operations/flate) | Flux render, Helm charts included, and the diff of a PR |
| `promtool` | unit tests of the Prometheus alert rules |
| `gh` | the PR comment of the diff, on GitHub Actions |
| `python3` + PyYAML, `git`, `curl` | the validation scripts |
| `node` 24 | the JavaScript actions (`actions/checkout`), run with the node of the job container on Forgejo |

Every binary is checked against the checksums published with its release.

## Image

`ghcr.io/legleo/ci-validate:1.<build number>`, built and pushed by `.github/workflows/build.yaml`
on every change of the `Dockerfile` on `main` (PRs are only built). Use it pinned by digest:

```yaml
container:
  image: ghcr.io/legleo/ci-validate:1.N@sha256:...
```

The versions are the `ARG`s of the `Dockerfile`. `KUBE_VERSION` follows the cluster and is updated
by hand; the others carry a `# renovate:` comment.
