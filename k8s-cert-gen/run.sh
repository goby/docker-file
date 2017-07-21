#!/bin/sh

cat <<'WelCome-Message'

     ______  __       ____                                  
    /\__  _\/\ \     /\  _`\                                
    \/_/\ \/\ \ \    \ \,\L\_\         __      __    ___    
       \ \ \ \ \ \  __\/_\__ \       /'_ `\  /'__`\/' _ `\  
        \ \ \ \ \ \L\ \ /\ \L\ \    /\ \L\ \/\  __//\ \/\ \ 
         \ \_\ \ \____/ \ `\____\   \ \____ \ \____\ \_\ \_\  
          \/_/  \/___/   \/_____/    \/___L\ \/____/\/_/\/_/   
                                       /\____/              
            with https://cfssl.org     \_/__/               
     This image will help you:
       * generate and sign your ca and cert
     Usage:
       * setup your envrionment, and remember mount /opt/cfssl/output dir to your target path
     Environment:
       Variable          DefaultValue                  Description
     -------------------+-----------------------------+---------------------------
       * SSL_EXPIRY      "87600h"                      Expiry of signed.
       * SSL_CA_CN       "Kubernetes Netease CA"       CA common name.
       * SSL_COUNTRY     "CN"
       * SSL_LOCATION    "HangZhou"
       * SSL_ORGNIZATION "NetEase"
       * SSL_ORG_UNIT    "Kubernetes"
       * SSL_STATE       "ZheJiang"
       * K8S_APISERVER   "127.0.0.1 10.0.0.1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local"
                                                       APIServer running hosts, please seperate with space
     Output Directory:
       * /opt/cfssl/output
     
     REMARK:
       * if ca.pem and ca-key.pem exist in output directory, this CA will be used.
         Otherwise new CA will be generated.
    
     Type `?` to get help
WelCome-Message

TEMPLATE=/opt/cfssl/template-csr.json
CACONFIG=/opt/cfssl/ca-config.json

cat >${TEMPLATE}<<EOF
{
  "CN": "SSL_CN",
  "hosts": [SSL_HOSTS],
  "key": { "algo": "rsa", "size": 2048 },
  "names": [
    {
      "C": "${SSL_COUNTRY}",
      "L": "${SSL_LOCATION}",
      "O": "SSL_ORGNIZATION",
      "OU": "${SSL_ORG_UNIT}",
      "ST": "${SSL_STATE}"
    }
  ]
}
EOF

cat >${CACONFIG}<<EOF
{
  "signing": {
    "default": { "expiry": "${SSL_EXPIRY}" },
    "profiles": {
      "server": {
        "usages": [ "signing", "key encipherment", "server auth" ],
        "expiry": "${SSL_EXPIRY}"
      },
      "client": {
        "usages": [ "signing", "key encipherment", "client auth" ],
        "expiry": "${SSL_EXPIRY}"
      }
    }
  }
}
EOF

CA_CERT=/opt/cfssl/output/ca.pem
CA_KEY=/opt/cfssl/output/ca-key.pem

if [ -f $CA_CERT -a -f $CA_KEY ]; then
    echo "CA found, all cert will gened by the CA."
elif [ ! -f $CA_CERT -a ! -f $CA_KEY ]; then
    echo "No CA found, generating CA cert..."
    sed "s/SSL_CN/${SSL_CA_CN}/g; s/SSL_ORGNIZATION/${SSL_ORGNIZATION}/g; s/SSL_ORG_UNIT/${SSL_ORG_UNIT}/g; /hosts/d" $TEMPLATE | \
        cfssl gencert -initca - | cfssljson -bare /opt/cfssl/output/ca
else
    echo "Only found part of ca key-pair, please checking your output dir"
    echo "Aborted."
    exit 1
fi

function _gencert() {
    sed "s/SSL_CN/$2/g; s/SSL_ORGNIZATION/$3/g; s/SSL_HOSTS/$4/g" $TEMPLATE | \
        cfssl gencert -ca=${CA_CERT} -ca-key=${CA_KEY} -config=${CACONFIG} -profile=$5 - | cfssljson -bare /opt/cfssl/output/$1
}

function gen_apiserver() {
    HOSTS=
    for h in $K8S_APISERVER; do
        HOSTS="${HOSTS}, \"$h\""
    done
    
    HOSTS=${HOSTS#,}
    
    echo "Generating kube-apiserver server-side certification..."
    echo "API Server hosts: ${HOSTS}"

    _gencert kube-apiserver-server system:apiserver system:masters "${HOSTS}" server
}

function gen_kubelet() {
    node=$1
    cn=system:node
    if [ x$node != "x" ]; then
        cn=$cn:$node
    fi
    echo "Generating kubelet client certification..."
    _gencert kubelet-client-$node $cn system:nodes "" client
}


function gen_admin() {
    echo "Generating kubectl(localhost) certification..."
    _gencert kube-admin kubernetes-admin system:masters "\"127.0.0.1\"" client
}

function gen_proxy() {
    echo "Generating kube-proxy client certification..."
    _gencert kube-proxy system:kube-proxy system:nodes "" client
}

function gen_controller_manager() {
    echo "Generating controller-manager certification..."
    _gencert kube-controller-manager system:kube-controller-manager system:masters "" client
}

function gen_scheduler() {
    echo "Generating scheduler certification..."
    _gencert kube-scheduler system:kube-scheduler system:masters "" client
}

function gen_all() {
    gen_apiserver
    gen_kubelet
    gen_admin
    gen_proxy
    gen_controller_manager
    gen_scheduler
}

function _help() {
    cat <<HelpMessage
gen_all
    Generate all server and client cert and key.
gen_apiserver
    Generate apiserver server cert and key.
gen_kubelet [<node-name>]
    Generate kubelet client cert and key, if node-name provided, the cn is system:node:<node-name>.
gen_admin
    Generate kubectl client cert and key.
gen_proxy
    Generate kube-proxy client cert and key.
gen_controller_manager
    Generate kube-controller-manager client cert and key.
gen_scheduler
    Generate kube-scheduler client cert and key.

HelpMessage
}

alias ?=_help

