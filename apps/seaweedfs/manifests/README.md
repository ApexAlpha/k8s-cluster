# SeaweedFS

This directory will contain SeaweedFS manifests.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SeaweedFS Cluster                             │
│                                                                  │
│   k3s-home             k3s-nuc              k3s-hetzner         │
│   ┌───────────┐       ┌───────────┐        ┌───────────┐        │
│   │  Master   │       │  Master   │        │  Master   │        │
│   │  Volume   │       │  Volume   │        │  Volume   │        │
│   │  Filer    │       │  Filer    │        │  Filer    │        │
│   └───────────┘       └───────────┘        └───────────┘        │
│        │                   │                     │               │
│        └───────────────────┴─────────────────────┘               │
│                            │                                     │
│                     K3s embedded etcd                           │
│                   (shared filer metadata)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Storage Tiers

- **NVMe (fast)**: Databases, configs, small files
- **HDD (warm)**: Media, backups, large blobs

## TODO

Manifests will be added in the SeaweedFS setup phase.
