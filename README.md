# SRS-Docker

## Description
SRS-Docker is a docker image for DCS World's SRS (Simple Radio Standalone) application. It is based on Ubuntu 22.04 and uses the latest version of SRS.

## Requirements
- Docker
- Wine directory for SRS persistence

## Installation
1. Clone the repository
2. Build the docker image
```bash
docker build -t srs-docker .
```
3. Run the docker image
```bash
docker compose up -d
```