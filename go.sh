#!/bin/bash
if [[ "$(find vendor/knative.dev/networking -maxdepth 0 -mindepth 0 -type l | wc -l)" == 0 ]]; then
  pushd vendor/knative.dev
  for D in networking pkg serving; do
    rm -rf ${D}
    ln -s ../../../${D}
  done
  popd
fi
if [ -z "${TAG}" ]; then
  TAG=$(date +%Y%m%d)
fi
export GOFLAGS=-mod=vendor
set -xeo pipefail
go build -o bin/manager ./cmd/manager
REP="library/hardened/kserve/kserve-controller"
docker build . -t 724664234782.dkr.ecr.us-east-1.amazonaws.com/${REP}:${TAG}
if [ -z "${PUSH}" ]; then
  docker push 724664234782.dkr.ecr.us-east-1.amazonaws.com/${REP}:${TAG}
fi
