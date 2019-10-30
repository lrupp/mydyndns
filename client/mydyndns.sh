#!/bin/sh
CONFIG='/etc/mydyndns.conf'
OLDIPFILE=/root/myip
TEMPFILE=$(mktemp "/tmp/myip.XXXXXX") || exit 1
LOGFILE='/var/log/mydyndns.log'
WHATSMYIPURL='http://www.example.com/cgi-bin/whatsmyip.cgi'
DYNHOSTNAME='myhost.dyn.example.com'
DNSSERVER='1.1.1.1'
REMOTEURL='https://www.example.com/cgi-bin/dyndns.pl'
REMOTEUSER='user'
REMOTEPASS='pass'
REMOTEHOST='myhost'
trap "rm -f $TEMPFILE" EXIT

function LOG(){
    DATE=$(date)
    echo "$DATE $1" >> "$LOGFILE"
}

function cleanup_and_exit(){
    local EXITCODE="$1"
    test -f "$TEMPFILE" && rm "$TEMPFILE"
    exit $EXITCODE
}

function submit_ip_via_curl(){
    LOG "Using wget"
    wget --no-proxy -o /dev/null --quiet --no-check-certificate "$REMOTEURL?username=$REMOTEUSER&password=$REMOTEPASS&hostname=$REMOTEHOST"
}

if [ -r "$CONFIG" ]; then
    . "$CONFIG"
else
    echo "Could not read $CONFIG - exiting" >&2
    cleanup_and_exit 1
fi

curl --fail --insecure $WHATSMYIPURL > "$TEMPFILE"
REMOTE_IP=$(host $DYNHOSTNAME $DNSSERVER | awk '" " { print $4 }' | tr -d '\n' )
NEW_IP=$(cat "$TEMPFILE")

if [ "$NEW_IP" != "$REMOTE_IP" ]; then
  if [ "$REMOTE_IP" != "found:" ]; then
    LOG "Old IP: $REMOTE_IP; new IP: $NEW_IP - updating"
    submit_ip_via_wget
  else
    LOG "DNS server $DNSSERVER does not know our host name $DYNHOSTNAME - please check the config"
  fi
else
  LOG "Still have $REMOTE_IP - no update needed"
fi
cleanup_and_exit "0"

