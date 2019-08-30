#!/bin/bash

ats_setup()
{
    settings_global_mc="/home/kylin-ksvd/.ksvd/settings.global.mc"
    settings_records="/etc/trafficserver/records.config"
    KSVD_BIN=/usr/lib/ksvd/bin/

    eval `grep ^UNIQB_ATS_ENABLED= "$settings_global_mc"`

    if [ "$UNIQB_ATS_ENABLED" = "yes" ]; then
        eval `grep ^UNIQB_ATS_IP= "$settings_global_mc"`
        eval `grep ^UNIQB_ATS_THRESHOLD_CPU= "$settings_global_mc"`
        eval `grep ^UNIQB_ATS_THRESHOLD_MEM= "$settings_global_mc"`
        eval `grep ^UNIQB_ATS_THRESHOLD_DISK= "$settings_global_mc"`
        eval `grep ^UNIQB_ATS_CLEANUP_STRATEGY= "$settings_global_mc"`

        # 1. 修改trafficserver配置
        if [[ "" != "$UNIQB_ATS_THRESHOLD_CPU" ]]; then
            if [[ "0" == "$UNIQB_ATS_THRESHOLD_CPU" ]]; then
                sed -i -e "s/^CONFIG proxy.config.exec_thread.autoconfig .*/CONFIG proxy.config.exec_thread.autoconfig INT 1/" $settings_records
            else
                sed -i -e "s/^CONFIG proxy.config.exec_thread.limit .*/CONFIG proxy.config.exec_thread.limit INT $UNIQB_ATS_THRESHOLD_CPU/" $settings_records
                sed -i -e "s/^CONFIG proxy.config.exec_thread.autoconfig .*/CONFIG proxy.config.exec_thread.autoconfig INT 0/" $settings_records
            fi
        fi
        if [[ "" != "$UNIQB_ATS_THRESHOLD_MEM" ]]; then
            sed -i -e "s/^CONFIG proxy.config.cache.ram_cache.size .*/CONFIG proxy.config.cache.ram_cache.size INT $UNIQB_ATS_THRESHOLD_MEM/" $settings_records
        fi
        if [[ "" != "$UNIQB_ATS_THRESHOLD_DISK" ]]; then
            echo "var/cache $UNIQB_ATS_THRESHOLD_DISK" > /etc/trafficserver/storage.config
        fi
        # 0表示CLFUS (Clocked Least Frequently Used by Size). 1表示 LRU (Least Recently Used)，默认为算法1
        if [[ "clfus" == "$UNIQB_ATS_CLEANUP_STRATEGY" ]]; then
            sed -i -e "s/^CONFIG proxy.config.cache.ram_cache.algorithm .*/CONFIG proxy.config.cache.ram_cache.algorithm INT 0/" $settings_records
        elif [[ "lru" == "$UNIQB_ATS_CLEANUP_STRATEGY" ]]; then
            sed -i -e "s/^CONFIG proxy.config.cache.ram_cache.algorithm .*/CONFIG proxy.config.cache.ram_cache.algorithm INT 1/" $settings_records
        fi
        systemctl enable trafficserver && systemctl restart trafficserver

        # 2. 透明代理启用
        if [[ "" != "$UNIQB_ATS_IP" ]]; then
            iptables -t nat -N KYLIN_TPROXY
            iptables -t nat -A KYLIN_TPROXY -p tcp -m tcp --dport 80 -j DNAT --to-destination $UNIQB_ATS_IP:3080
            iptables -t nat -A KYLIN_TPROXY -p tcp -m tcp --dport 443 -j DNAT --to-destination $UNIQB_ATS_IP:3443
            iptables -t nat -A PREROUTING ! -s $UNIQB_ATS_IP/32 -p tcp -m tcp --dport 80 -j KYLIN_TPROXY
            iptables -t nat -A PREROUTING ! -s $UNIQB_ATS_IP/32 -p tcp -m tcp --dport 443 -j KYLIN_TPROXY
        fi

    else
        # 1. 透明代理禁用
        iptables -t nat -S PREROUTING | grep "^-A" | grep KYLIN_TPROXY | sed -e 's/^-A/-D/' -e 's/^/iptables -t nat /' | sh -e
        iptables -t nat -F KYLIN_TPROXY
        iptables -t nat -X KYLIN_TPROXY
        # 2. 停止缓存服务
        systemctl disable trafficserver && systemctl stop trafficserver
    fi
}

ats_setup
