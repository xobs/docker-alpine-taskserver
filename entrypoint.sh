#!/bin/sh

# Certificate configuration
: ${CN:="localhost"}
: ${ORGANIZATION:="Taskserver User"}
: ${COUNTRY:="US"}
: ${STATE:="California"}
: ${LOCALITY:="Downtown"}
: ${BITS:=4096}

# Server configuration
: ${IP:="0.0.0.0"}
: ${PID:="/var/run/taskd.pid"}
: ${PORT:="53589"}

config_path=/data
cert_path=${config_path}/certs
log_file=/dev/fd/1
le_path=/letsencrypt/live/${CN}
taskd="/usr/bin/taskd"
certtool=$(which gnutls-certtool || which certtool)

# Ensure we have certtool installed
if [ -z "$certtool" ]
then
    echo "ERROR: No certtool found" >&2
    exit 1
fi

_generate_ca() {
    # Create a CA key.
    ${certtool} \
        --generate-privkey \
        --bits $BITS \
        --outfile ${cert_path}/ca.key.pem

    chmod 600 ${cert_path}/ca.key.pem

    # Sign a CA cert.
    cat <<EOF >/tmp/ca.info
organization = $ORGANIZATION
cn = $CN
country = $COUNTRY
state = $STATE
locality = $LOCALITY
ca
cert_signing_key
EOF

    ${certtool} \
        --generate-self-signed \
        --load-privkey ${cert_path}/ca.key.pem \
        --template /tmp/ca.info \
        --outfile ${cert_path}/ca.cert.pem

    chmod 644 ${cert_path}/ca.cert.pem
    rm /tmp/ca.info
}

_generate_client() {
    local name=client
    if [ $# -gt 0 ] ; then
      name=$1
    fi

    # Create a client key.
    ${certtool} \
      --generate-privkey \
      --bits $BITS \
      --outfile ${cert_path}/${name}.key.pem

    # Sign a client cert with the key.
    chmod 644 ${cert_path}/${name}.key.pem
    cat <<EOF >/tmp/client.info
organization = $ORGANIZATION
cn = $CN
tls_www_client
encryption_key
signing_key
EOF

    ${certtool} \
      --generate-certificate \
      --load-privkey ${cert_path}/${name}.key.pem \
      --load-ca-certificate ${cert_path}/ca.cert.pem \
      --load-ca-privkey ${cert_path}/ca.key.pem \
      --template /tmp/client.info \
      --outfile ${cert_path}/${name}.cert.pem

    chmod 644 ${cert_path}/${name}.cert.pem
    rm /tmp/client.info
}

_cert_config() {
    if [ ! -e ${cert_path}/ca.cert.pem ]
    then
        mkdir -p ${cert_path}
        _generate_ca
        _generate_client
    fi

    ${taskd} config server.key ${le_path}/privkey.pem
    ${taskd} config server.cert ${le_path}/fullchain.pem
    #${taskd} config server.crl ${pki_path}/unused.pem
    ${taskd} config client.key ${cert_path}/client.key.pem
    ${taskd} config client.cert ${cert_path}/client.cert.pem
    ${taskd} config ca.cert ${cert_path}/ca.cert.pem
}

# Create a new configuration file
if [ ! -f ${config_path}/config ]; then
    ${taskd} init --data ${config_path}
    ${taskd} config log ${log_file} --data ${config_path}
    ${taskd} config pid.file ${PID} --data ${config_path}
    ${taskd} config server ${IP}:${PORT} --data ${config_path}
else
    if ! grep -Fxq "log=${log_file}" ${config_path}/config; then
        ${taskd} config log ${log_file} --data ${config_path}
    fi

    if ! grep -Fxq "pid.file=${PID}" ${config_path}/config; then
        ${taskd} config pid.file ${PID} --data ${config_path}
    fi
    
    if ! grep -Fxq "server=${IP}:${PORT}" ${config_path}/config; then
        ${taskd} config server ${IP}:${PORT} --data ${config_path}
    fi

fi

_cert_config
exec ${taskd} server --data ${config_path}
