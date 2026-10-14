#!/bin/sh

case "$1" in
    bound|renew) ;;
    *) exit 0 ;;
esac

RESOLV_CONF=/etc/resolv.conf
PROBE=api.tenclass.net
server=$(awk '/^nameserver / { print $2; exit }' "$RESOLV_CONF")
[ -n "$server" ] || exit 0
command -v nslookup >/dev/null 2>&1 || exit 0

ipv4=$(nslookup -type=A "$PROBE" "$server" 2>&1)
printf '%s\n' "$ipv4" | grep -q "Name:.*$PROBE" || exit 0
ipv6=$(nslookup -type=AAAA "$PROBE" "$server" 2>&1)
printf '%s\n' "$ipv6" | grep -q NXDOMAIN || exit 0

for fallback in 223.5.5.5 119.29.29.29; do
    answer=$(nslookup -type=A "$PROBE" "$fallback" 2>&1)
    printf '%s\n' "$answer" | grep -q "Name:.*$PROBE" || continue
    answer=$(nslookup -type=AAAA "$PROBE" "$fallback" 2>&1)
    printf '%s\n' "$answer" | grep -q 'Non-authoritative answer:\|Name:' || continue
    tmpfile=$(mktemp) || exit 1
    printf 'nameserver %s # qzdesk DNS compatibility\n' "$fallback" > "$tmpfile"
    awk '!/^nameserver /' "$RESOLV_CONF" >> "$tmpfile"
    cat "$tmpfile" > "$RESOLV_CONF"
    rm -f "$tmpfile"
    logger -t qzdesk-dns "DNS $server returned conflicting A/AAAA results; using $fallback first"
    exit 0
done
logger -t qzdesk-dns "DNS $server returned conflicting A/AAAA results; no working fallback"
exit 0
