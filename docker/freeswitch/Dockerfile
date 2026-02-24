FROM debian:bookworm-slim

ARG fs_repo_user
ARG fs_repo_password

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  gnupg2 wget ca-certificates lsb-release && \
  wget --http-user=${fs_repo_user} --http-password=${fs_repo_password} \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && \
  echo "machine freeswitch.signalwire.com login ${fs_repo_user} password ${fs_repo_password}" > /etc/apt/auth.conf && \
  echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" \
    > /etc/apt/sources.list.d/freeswitch.list && \
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    freeswitch \
    freeswitch-conf-vanilla \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-event-socket \
    freeswitch-mod-sofia \
    freeswitch-mod-commands \
    freeswitch-mod-dptools \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-sndfile \
    freeswitch-mod-native-file \
    freeswitch-mod-tone-stream \
    freeswitch-mod-say-en \
    freeswitch-mod-loopback \
    freeswitch-mod-opus \
    freeswitch-mod-local-stream && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf

RUN mkdir -p /var/log/freeswitch /usr/share/freeswitch/recordings

EXPOSE 5060/udp 5060/tcp 8021/tcp

CMD ["freeswitch", "-nonat", "-nf"]

