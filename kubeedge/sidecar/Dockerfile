FROM alpine:3.14

RUN apk add --update iptables curl bash
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]