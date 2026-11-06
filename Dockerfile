# ---------- Stage 1: German prompts from Debian ----------
# Alpine has no German sound package, so the prompt files are taken from
# Debian's asterisk-prompt-de. They are plain audio files and work anywhere.
FROM debian:trixie-slim AS prompts
RUN set -eux; \
    apt-get update; \
    cd /tmp; \
    apt-get download asterisk-prompt-de; \
    dpkg-deb -x asterisk-prompt-de_*.deb /out; \
    src="$(find /out -type d -path '*/sounds/de' | head -n1)"; \
    test -n "$src"; \
    mkdir -p /prompts-de; \
    cp -a "$src"/. /prompts-de/

# ---------- Stage 2: Asterisk on Alpine ----------
FROM alpine:3.24

ARG ASTERISK_UID=1000
ENV TZ=Europe/Berlin

RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache \
        asterisk asterisk-fax asterisk-sounds-en \
        tzdata ca-certificates tiff-tools s-nail msmtp; \
    # msmtp as sendmail replacement (used by voicemail and s-nail)
    ln -sf /usr/bin/msmtp /usr/sbin/sendmail; \
    # Pin the time zone
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    # Fixed UID/GID so file permissions on the host are predictable
    deluser asterisk 2>/dev/null || true; \
    delgroup asterisk 2>/dev/null || true; \
    addgroup -g "$ASTERISK_UID" asterisk; \
    adduser -S -D -H -u "$ASTERISK_UID" -G asterisk -h /var/lib/asterisk -s /sbin/nologin asterisk; \
    # The user's configuration is mounted to /etc/asterisk
    rm -rf /etc/asterisk/*; \
    # Alpine installs the English sounds to /usr/share/asterisk/sounds, but Asterisk
    # looks in its data directory /var/lib/asterisk/sounds. Link them so the
    # English set (incl. the voicemail beep) is available as fallback.
    mkdir -p /var/lib/asterisk/sounds; \
    ln -sfn /usr/share/asterisk/sounds/en /var/lib/asterisk/sounds/en; \
    # Status page: serve /opt/status under /static/status/
    mkdir -p /var/lib/asterisk/static-http; \
    ln -sfn /opt/status /var/lib/asterisk/static-http/status; \
    mkdir -p /var/run/asterisk /var/spool/asterisk/fax /var/log/asterisk /var/lib/asterisk/keys; \
    chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/spool/asterisk \
        /var/log/asterisk /var/run/asterisk

COPY --from=prompts /prompts-de/ /var/lib/asterisk/sounds/de/
COPY fax2mail.sh faxsent.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/fax2mail.sh /usr/local/bin/faxsent.sh

HEALTHCHECK --interval=60s --timeout=5s \
    CMD asterisk -rx "core show uptime" >/dev/null || exit 1

CMD ["asterisk", "-f", "-U", "asterisk", "-G", "asterisk", "-vvv"]
