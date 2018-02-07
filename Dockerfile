FROM alpine:3.5

MAINTAINER Sean Cross <sean@xobs.io>

# Keep this safe somewhere, as it's the taskd config dir
VOLUME /data
ENV TASKDDATA /data

# Mount this as readonly
VOLUME /letsencrypt

RUN apk add --no-cache taskd taskd-pki

COPY entrypoint.sh /

WORKDIR /

EXPOSE 53589

CMD [ "/entrypoint.sh" ]
