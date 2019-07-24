function do_global_pre_remap()
    local method = ts.client_request.get_method()
    if not method or method ~= 'CONNECT' then
        return
    end

    local url_host = ts.client_request.get_url_host()
    --if url_host ~= 'jdvodrvfb210d.vod.126.net' then
    if url_host == 'www.fuck.com' then
        return
    end

    -- finally route method CONNECT to self, for certifier middle-in-man
    ts.server_request.server_addr.set_addr("127.0.0.1", 3443, TS_LUA_AF_INET)
end

function do_global_os_dns()
    local method = ts.client_request.get_method()
    if not method or method ~= 'CONNECT' then
        return
    end

    local url_host = ts.client_request.get_url_host()
    --if url_host ~= 'jdvodrvfb210d.vod.126.net' then
    if url_host == 'www.fuck.com' then
        return
    end

    -- finally route method CONNECT to self, for certifier middle-in-man
    ts.server_request.server_addr.set_addr("127.0.0.1", 3443, TS_LUA_AF_INET)
end
