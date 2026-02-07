# GCompris — Educational Activities (Dutch)

Browser-accessible [GCompris](https://gcompris.net/) via [KasmVNC](https://www.kasmweb.com/),
exposed on **https://lezen.k8s.hu.ls**.

## Prerequisites

### 1. Build & push the container image

```bash
cd homelab/gcompris

docker build -t ghcr.io/apexalpha/gcompris-kasm:latest .
docker push ghcr.io/apexalpha/gcompris-kasm:latest
```

> **Tip:** add a GitHub Actions workflow to rebuild on push — see below.

### 2. Create the VNC password secret

```bash
kubectl create namespace gcompris 2>/dev/null || true

kubectl -n gcompris create secret generic gcompris-vnc \
  --from-literal=password='<choose-a-password>'
```

## Architecture

```
browser ──▶ Traefik (TLS) ──▶ KasmVNC :6901 (self-signed) ──▶ GCompris-Qt
             lezen.k8s.hu.ls    ServersTransport insecureSkipVerify
```

- **Image:** Custom build on `kasmweb/core-ubuntu-jammy:1.16.0`
- **Language:** `nl_NL.UTF-8` — GCompris auto-detects the locale
- **Persistence:** User profile stored on SeaweedFS PVC (2 Gi)
- **Shared memory:** 512 Mi `emptyDir` mounted at `/dev/shm` (required by KasmVNC)

## Optional: GitHub Actions auto-build

Create `.github/workflows/gcompris-image.yaml`:

```yaml
name: Build GCompris KASM image
on:
  push:
    paths: ["homelab/gcompris/Dockerfile", "homelab/gcompris/custom_startup.sh"]
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: homelab/gcompris
          push: true
          tags: ghcr.io/apexalpha/gcompris-kasm:latest
```
