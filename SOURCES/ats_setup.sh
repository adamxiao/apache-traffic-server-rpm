#!/bin/bash

PROXY_IP=127.0.0.1

usage()
{
    echo >&2 "usage: $0 enable|disable [proxy_ip]"
}

add_proxy()
{
    iptables -t nat -N KYLIN_TPROXY
    iptables -t nat -A KYLIN_TPROXY -p tcp -m tcp --dport 80 -j DNAT --to-destination $PROXY_IP:3080
    iptables -t nat -A KYLIN_TPROXY -p tcp -m tcp --dport 443 -j DNAT --to-destination $PROXY_IP:3443
    iptables -t nat -A PREROUTING ! -s $PROXY_IP/32 -p tcp -m tcp --dport 80 -j KYLIN_TPROXY
    # disable https transparent proxy
    #iptables -t nat -A PREROUTING ! -s $PROXY_IP/32 -p tcp -m tcp --dport 443 -j KYLIN_TPROXY
}

del_proxy()
{
    iptables -t nat -S PREROUTING | grep "^-A" | grep KYLIN_TPROXY | sed -e 's/^-A/-D/' -e 's/^/iptables -t nat /' | sh -e
    iptables -t nat -F KYLIN_TPROXY
    iptables -t nat -X KYLIN_TPROXY
}

if [[ "$#" -lt 1 ]]; then
    usage
    exit 1
fi
op=$1
if [[ "enable" == "$op" ]]; then
    if [[ "$#" -lt 2 ]]; then
        usage
        exit 2
    fi
    PROXY_IP=$2
    systemctl start trafficserver
    del_proxy
    add_proxy
elif [[ "disable" == "$op" ]]; then
    del_proxy
    systemctl stop trafficserver
else
    usage
    exit 3
fi
