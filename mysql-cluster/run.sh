#!/bin/bash

# original script: https://github.com/g17/MySQL-Cluster/blob/master/run.sh

KUBE_NAMESPACE=$(</var/run/secrets/kubernetes.io/serviceaccount/namespace)
KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
KUBE_SERVER=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT

KUBE_ORDINAL=${HOSTNAME##*-}
KUBE_PARENT=${HOSTNAME%-*}

MYSQL_CLUSTER_BIN=${MYSQL_CLUSTER_HOME}/bin
MYSQL_MANAGEMENT_SERVER=${KUBE_PARENT}-0.${KUBE_PARENT}
MYSQL_MANAGEMENT_PORT=1186

INITIAL=""
RELOAD="--reload"
if [ ! -e ${MYSQL_CLUSTER_DATA}/.initial ]; then
    echo "First execution detected. Using --initial parameter."
    INITIAL="--initial"
    RELOAD=""
    touch ${MYSQL_CLUSTER_DATA}/.initial
else
    echo "Pre-initialized installation detected. Using --reload parameter."
fi

function kube_label_patch() {
    KEY=$1
    VALUE=$2
    curl -sSk -XPATCH -H "Authorization: Bearer ${KUBE_TOKEN}" -H "Content-Type:application/json-patch+json" \
       -d "[{\"op\": \"add\", \"path\": \"/metadata/labels/$KEY\", \"value\": \"$VALUE\"}]" \
       $KUBE_SERVER/api/v1/namespaces/$KUBE_NAMESPACE/pods/$HOSTNAME
}

function role_discover() {
    ORDINAL=$1
    if [ 0 -eq $ORDINAL ]; then
        echo ndb_mgmd
    elif [ 1 -eq $((ORDINAL % 2)) ]; then
        echo ndbd
    elif [ 0 -eq $((ORDINAL % 2)) ]; then
        echo mysqld
    fi
}

function run_ndbd() {
    kube_label_patch role ${KUBE_PARENT}-data
    exec ${MYSQL_CLUSTER_BIN}/ndbd --nodaemon ${INITIAL} --connect-string="nodeid=${KUBE_ORDINAL};host=${MYSQL_MANAGEMENT_SERVER}:${MYSQL_MANAGEMENT_PORT}"
}

function run_mysqld() {
    echo "Starting mysqld..."
    kube_label_patch role ${KUBE_PARENT}-api
    if [ -n "$INITIAL"  ]; then
        exec ${MYSQL_CLUSTER_BIN}/mysqld --initialize-insecure --user=${MYSQL_USER} --datadir=${MYSQL_CLUSTER_DATA}
    fi
    exec ${MYSQL_CLUSTER_BIN}/mysqld_safe --ndbcluster --ledir=${MYSQL_CLUSTER_BIN} --ndb-connectstring="nodeid=${KUBE_ORDINAL};host=${MYSQL_MANAGEMENT_SERVER}"
}

function run_ndb_mgmd() {
    echo "Starting ndb_mgmd..."
    echo "Discovery replicas..."
    
    kube_label_patch role ${KUBE_PARENT}-ndb-mgmd

    if [ -f ${MYSQL_CLUSTER_CONFIG} ]; then
        echo "Cluster config existing, use ${MYSQL_CLUSTER_CONFIG}"
    else
        REPLICAS=$(curl -sSk -H "Authorization: Bearer ${KUBE_TOKEN}" $KUBE_SERVER/apis/apps/v1beta1/namespaces/$KUBE_NAMESPACE/statefulsets/$KUBE_PARENT | jq -r ".spec.replicas")
        # the first node is management
        REPLICAS=$((REPLICAS - 1))
        DATA_REPLICAS=$((REPLICAS/2))
        cat > ${MYSQL_CLUSTER_CONFIG} <<EOF
[NDBD DEFAULT]
NoOfReplicas=${DATA_REPLICAS}
DataMemory=80M
IndexMemory=18M
datadir=${MYSQL_CLUSTER_DATA}

[NDB_MGMD]
NodeId=254
datadir=${MYSQL_CLUSTER_DATA}
hostname=${HOSTNAME}.${KUBE_PARENT}

EOF
        i=0
        while [ $i -lt ${REPLICAS} ]; do
            cat >> ${MYSQL_CLUSTER_CONFIG} <<EOF
[NDBD]
NodeId=$((i+1))
hostname=${KUBE_PARENT}-$((i+1)).${KUBE_PARENT}

[MYSQLD]
NodeId=$((i+2))
hostname=${KUBE_PARENT}-$((i+2)).${KUBE_PARENT}
EOF
            i=$((i+2))
        done
    fi

    exec ${MYSQL_CLUSTER_BIN}/ndb_mgmd --nodaemon ${RELOAD} ${INITIAL} -f ${MYSQL_CLUSTER_CONFIG} --ndb-nodeid=254
}

ROLE=$(role_discover ${KUBE_ORDINAL})

echo "Detecting this node role: $ROLE"

run_$ROLE
