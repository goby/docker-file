#!/bin/bash

set -o errexit

TAGNAME=$1
BASEDIR=$PWD

if [ -z "$TAGNAME" ]; then
   echo "Usage: $0 <tagname>"
   exit 1
fi

# build from source
docker run --rm -v $BASEDIR/.src:/go/src -v $BASEDIR/.bin:/go/bin golang:alpine /bin/sh -c "apk update && \
   apk add git && \
   go get -d github.com/driskell/log-courier && \
   cd /go/src/github.com/driskell/log-courier && \
   go generate . ./lc-admin && \
   go install . ./lc-admin ./lc-tlscert"

docker build -t $TAGNAME .

