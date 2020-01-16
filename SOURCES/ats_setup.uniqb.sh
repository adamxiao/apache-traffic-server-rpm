#!/bin/bash

gen_pac_file()
{
	pac_file=$1
	cat > $pac_file << EOF
function FindProxyForURL(url, host)
{
	/* Normalize the URL for pattern matching */
	host = host.toLowerCase();

	var KYLIN_PROXY = "" +
		"DIRECT"; // 默认走代理，如果失败，则直接连接

	var jz_sites = [
		'jdvodrvfb210d.vod.126.net',
	];

	var jz_domain = [
		'.icourse163.org',
		'.xuetangx.com',
		'.mooc.com',
		'.cnmooc.org',
		'.zhihuishu.com',
		'.chinesemooc.org',
	];

	for (var i = 0; i < jz_sites.length; i++) {
		if (host == jz_sites[i]) {
			return KYLIN_PROXY;
		}
	}

	for (var i = 0; i < jz_domain.length; i++) {
		if (dnsDomainIs(host, jz_domain[i])) {
			return KYLIN_PROXY;
		}
	}

	return 'DIRECT';
}
EOF
}

pac_setup()
{
	PROXY_IP="$1"
	PROXY_PORT="${2:-3080}"
	pac_file="/home/kylin-ksvd/.ksvd-local/kylin_proxy.pac"
	if [[ ! -f $pac_file ]]; then
		gen_pac_file $pac_file
	fi

	if [[ "" != "$PROXY_IP" ]]; then
		sed -i -e "s/^\\s*var\\sKYLIN_PROXY\\s.*$/\\tvar KYLIN_PROXY = \"PROXY ${PROXY_IP}:${PROXY_PORT}; \" +/" $pac_file
	else
		sed -i -e 's/^\s*var\sKYLIN_PROXY\s.*$/\tvar KYLIN_PROXY = "" +/' $pac_file
	fi
}

ats_setup()
{
    settings_global_mc="/home/kylin-ksvd/.ksvd/trafficServer.settings"
    settings_records="/etc/trafficserver/records.config"
    KSVD_BIN=/usr/lib/ksvd/bin/

    eval `grep ^UNIQB_ATS_ENABLED= "$settings_global_mc"`

    if [ "$UNIQB_ATS_ENABLED" = "yes" ]; then
        eval `grep ^UNIQB_ATS_IP= "$settings_global_mc"`
        eval `grep ^UNIQB_ATS_PORT= "$settings_global_mc"`
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
            mem_size=$((1024*$UNIQB_ATS_THRESHOLD_MEM))
            if [[ "0" == "$UNIQB_ATS_THRESHOLD_MEM" ]]; then
                mem_size=-1
            fi
            sed -i -e "s/^CONFIG proxy.config.cache.ram_cache.size .*/CONFIG proxy.config.cache.ram_cache.size INT $mem_size/" $settings_records
        fi
        if [[ "" != "$UNIQB_ATS_THRESHOLD_DISK" ]]; then
            if [[ "0" == "$UNIQB_ATS_THRESHOLD_DISK" ]]; then
                UNIQB_ATS_THRESHOLD_DISK=256
            fi
            echo "var/cache ${UNIQB_ATS_THRESHOLD_DISK}M" > /etc/trafficserver/storage.config
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
            # disable https transparent proxy
            #iptables -t nat -A KYLIN_TPROXY -p tcp -m tcp --dport 443 -j DNAT --to-destination $UNIQB_ATS_IP:3443
            iptables -t nat -A PREROUTING ! -s $UNIQB_ATS_IP/32 -p tcp -m tcp --dport 80 -j KYLIN_TPROXY
            iptables -t nat -A PREROUTING ! -s $UNIQB_ATS_IP/32 -p tcp -m tcp --dport 443 -j KYLIN_TPROXY
        fi

        # 3. 更新pac文件
        pac_setup $UNIQB_ATS_IP $UNIQB_ATS_PORT

    else
        # 1. 透明代理禁用
        iptables -t nat -S PREROUTING | grep "^-A" | grep KYLIN_TPROXY | sed -e 's/^-A/-D/' -e 's/^/iptables -t nat /' | sh -e
        iptables -t nat -F KYLIN_TPROXY
        iptables -t nat -X KYLIN_TPROXY
        # 2. 停止缓存服务
        systemctl disable trafficserver && systemctl stop trafficserver

        # 3. 更新pac文件
        pac_setup
    fi
}

ats_setup
