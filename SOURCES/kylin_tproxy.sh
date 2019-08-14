#!/bin/bash

# yum install iptables-services -y
# systemctl enable iptables

PROXY_IP=""

IPTABLE_CONF=/etc/sysconfig/iptables

proxy_save()
{
    if [[ -z "$PROXY_IP" ]];then
        > $IPTABLE_CONF
        return
    fi

    cat > $IPTABLE_CONF << EOF
# kylin tranparent proxy
*nat
-A PREROUTING ! -s $PROXY_IP/32 -p tcp -m tcp --dport 80 -j DNAT --to-destination $PROXY_IP:3080
-A PREROUTING ! -s $PROXY_IP/32 -p tcp -m tcp --dport 443 -j DNAT --to-destination $PROXY_IP:3443
COMMIT
EOF

}

add_proxy()
{
    # get rules from tproxy config file
    if [[ ! -f "$IPTABLE_CONF" ]]; then
        return
    fi

    cat $IPTABLE_CONF | grep "^-A" | sed -e 's/^/iptables -t nat /' | sh
}

del_proxy()
{
    # get rules from tproxy config file
    if [[ ! -f "$IPTABLE_CONF" ]]; then
        return
    fi

    cat $IPTABLE_CONF | grep "^-A" | sed -e 's/^-A/-D/' -e 's/^/iptables -t nat /' | sh
}

usage()
{
    echo >&2 "usage: $0 enable|disable [proxy_ip]"
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
    proxy_save
    add_proxy
elif [[ "disable" == "$op" ]]; then
    del_proxy
    proxy_save
else
    usage
    exit 3
fi
