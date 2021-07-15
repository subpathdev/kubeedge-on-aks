FROM cruizba/ubuntu-dind:19.03.11

RUN curl -L https://github.com/kubeedge/kubeedge/releases/download/v1.7.1/kubeedge-v1.7.1-linux-amd64.tar.gz -o kubeedge-v1.7.1-linux-amd64.tar.gz && \
    tar xfz kubeedge-v1.7.1-linux-amd64.tar.gz && \
    cp kubeedge-v1.7.1-linux-amd64/edge/edgecore /usr/local/bin/edgecore && \
    rm -rf kubeedge-v1.7.1-linux-amd64 kubeedge-v1.7.1-linux-amd64.tar.gz

RUN curl -L https://www.emqx.io/downloads/broker/v4.3.5/emqx-ubuntu20.04-4.3.5-amd64.deb -o /tmp/emqx-ubuntu20.04-4.3.5-amd64.deb && \
    dpkg -i /tmp/emqx-ubuntu20.04-4.3.5-amd64.deb && \
    rm /tmp/emqx-ubuntu20.04-4.3.5-amd64.deb

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /etc/kubeedge/config
RUN mkdir -p /kubeedge

COPY template /kubeedge/

COPY config/ca /etc/kubeedge/ca/
COPY config/certs /etc/kubeedge/certs/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]