MySQL Cluster
===

This docker image is based on [https://github.com/g17/MySQL-Cluster](https://github.com/g17/MySQL-Cluster)


## About this image

This image is a `debian:wheezy-slim` with `mysqld`, `ndbd`, `ndb_mgmd` binaries, to bootstrap a [MySQL Cluster](https://www.mysql.com/products/cluster).

* Version: 7.5.6
* Base image: `debian:wheezy-slim`

## Usage

This image used by kubernetes with statefulsets.

1. Create some persistent volumns and a persistent volumn claim.
2. Create a statefulset with this image.
3. The pod will auto create manager, data node and api node.

The first pod will always be manager, and the odds are data node, the evens are api nodes.
