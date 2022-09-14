FROM ubuntu:latest

ENV TERM=xterm
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y

COPY docker/scripts/* /usr/local/bin/

RUN install-packages.sh dnsutils iproute2 wireguard wireguard-dkms wireguard-tools

SHELL ["/bin/bash"]

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/local/bin/run.sh" ]
