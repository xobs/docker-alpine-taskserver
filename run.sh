#!/bin/sh

certKey="client.cert client.key server.cert server.key server.crl ca.cert
        ca.key"
pkiPath="/usr/share/taskd/pki"
taskdCmd="/usr/bin/taskd"

: ${cn:="localhost"}
: ${data:="/var/lib/taskd"}
: ${ip:="127.0.0.1"}
: ${log:="/var/log/taskd.log"}
: ${pid:="/var/run/taskd.pid"}
: ${port:="53589"}

_generateCertKey () {
    cd ${pkiPath}
    sed -i "s@^CN=.*@CN=${cn}@g" vars
    ./generate
    cp *.pem ${data}
}

_certConfig () {
    for ck in ${certKey}; do
        ${taskdCmd} config ${ck} ${data}/${ck}.pem --data ${data}
    done
}

if [ ! -f ${data}/config ]; then
    ${taskdCmd} init --data ${data}
    ${taskdCmd} config log ${log} --data ${data}
    ${taskdCmd} config pid.file ${pid} --data ${data}
    ${taskdCmd} config server ${ip}:${port} --data ${data}
    _generateCertKey
    _certConfig
else
    if ! grep -Fxq "log=${log}" ${data}/config; then
        ${taskdCmd} config log ${log} --data ${data}
    fi

    if ! grep -Fxq "pid.file=${pid}" ${data}/config; then
        ${taskdCmd} config pid.file ${pid} --data ${data}
    fi
    
    if ! grep -Fxq "server=${ip}:${port}" ${data}/config; then
        ${taskdCmd} config server ${ip}:${port} --data ${data}
    fi

    if ! grep -Fxq "CN=${cn}" ${pkiPath}/vars; then
        sed -i "s@^CN=.*@CN=${cn}@g" ${pkiPath}/vars
    fi
    
    for file in ${certKey}; do
        if [ ! -f ${data}/${file}.pem ]; then
            _generateCertKey
            _certConfig
            break
        fi
    done
fi

${taskdCmd} server --data ${data}
