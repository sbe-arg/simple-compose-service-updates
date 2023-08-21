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
      contents: write
      pull-requests: write
    steps:

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
          default_branch: 'main'
          skips: 'mongodb:6,postgresql-repmgr:15' # examples
        env:
          GH_TOKEN: ${{ github.token }} # required
```

## requirements:

- your compose files must be on your repo root.
- your compose files must match '\*compose\*.yaml' or '\*compose\*.yml'
- your images in compose files must include the full registry: 
  - docker.io/somecompany/theimage:x.x.x
  - mcr.microsoft.com/part/theimage:x.x.x

## what for:

- find compose services and bump them using prs

## supported registries

- dockerhub
- microsoft mcr
- other? open an issue or open pr

## what does it look like

- runs: [link](https://github.com/sbe-arg/simple-compose-service-updates/actions/workflows/simple.yml)
- releases: [link](https://github.com/sbe-arg/simple-compose-service-updates/releases)
- tags: [link](https://github.com/sbe-arg/simple-compose-service-updates/tags)
