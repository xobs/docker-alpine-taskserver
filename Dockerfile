FROM alpine:3.5

MAINTAINER Matthieu Monnier <matthieu.monnier@enalean.com>

RUN apk add --no-cache taskd taskd-pki \
    && mkdir -p /var/lib/taskd

COPY run.sh /usr/local/bin/

WORKDIR /usr/local/bin

CMD [ "run.sh" ]
