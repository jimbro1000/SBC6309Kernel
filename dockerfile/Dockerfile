FROM debian:bookworm
WORKDIR /usr/local/app

RUN apt update && apt install -y wget
RUN wget -qO- 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x26318813399a679f' > /etc/apt/keyrings/www.6809.org.uk.asc
ADD www.6809.org.uk.sources /etc/apt/sources.list.d/
RUN apt update && apt install -y asm6809
COPY --chmod=777 build.sh /usr/local.app/build.sh

ENTRYPOINT ["/usr/local.app/build.sh", "${SRC}"]
