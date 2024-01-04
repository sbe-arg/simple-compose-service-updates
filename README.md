# simple-compose-service-updates

## USAGE

```yaml
with:
  default_branch: 'main|master|other' # defaults to 'master'
  skips: 'mongodb:6' # defaults to '', example: 'skip:1,other:3'
```

```yaml
name: compose-service-updates

on:
  push:
    branches:
      - master

permissions:
  contents: read
  pull-requests: read

jobs:

  flow:
    runs-on: ubuntu-22.04
    permissions:
    permissions:
      contents: write
      pull-requests: write
      packages: read
    steps:

      - name: Log in to Github Container registry 
        # needed in case you need to pull private images within the same github organization, place before checkout
        uses: docker/login-action@343f7c4344506bcbf9b4de18042ae17996df046d # v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: actions/checkout@c85c95e3d7251135ab7dc9ce3241c5835cc595a9 # v3.5.3
        with:
          fetch-depth: '0'

      - name: setup-git
        run: |
          git config --global user.name "GitHub Actions"
          git config --global user.email "actions@github.com"

      - name: simple-compose-service-updates
        uses: sbe-arg/simple-compose-service-updates@v0.1.0 # use sha pinning when possible
        with:
          default_branch: 'main|master|other' # defaults to 'main'
          skips: 'mongodb:6,postgresql-repmgr:15' # examples
          ignore: 'alertmanager'
          prs: 'skip|generate' # defaults to 'generate'
        env:
          GH_TOKEN: ${{ github.token }} # required
```

## requirements:

- your compose files must be on your repo root.
- your compose files must match '\*compose\*.yaml' or '\*compose\*.yml'
- your images in compose files must include the full registry: 
  - `docker.io/somecompany/theimage:x.x.x` (ie, docker.io/grafana/grafana:10.0.1)
  - `mcr.microsoft.com/part/theimage:x.x.x` (ie, mcr.microsoft.com/azure-cli:2.50.0)
  - `gcr.io/project/image:x.x.x` (ie, gcr.io/cadvisor/cadvisor:v0.47.1)
  - `ghcr.io/username/image:x.x.x` (ie, ghcr.io/swissbuechi/one-time-secret:1.0.10)

## what for:

- find compose services and bump them using prs

## supported registries

- dockerhub
- microsoft mcr
- google gcr
- github packages ghcr (public images)
- other? open an issue or open pr

## what does it look like

- runs: [link](https://github.com/sbe-arg/simple-compose-service-updates/actions/workflows/simple.yml)
- releases: [link](https://github.com/sbe-arg/simple-compose-service-updates/releases)
- tags: [link](https://github.com/sbe-arg/simple-compose-service-updates/tags)
