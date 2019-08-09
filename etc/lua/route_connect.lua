-- route_connect.lua
function do_global_pre_remap()
    local method = ts.client_request.get_method()
    if not method or method ~= 'CONNECT' then
        return
    end

    local url_host = ts.client_request.get_url_host()
    if url_host == 'www.example.com' then
    --if url_host ~= 'www.example.com' then
        return
    end

    -- finally route method CONNECT to self, for certifier middle-in-man
    ts.server_request.server_addr.set_addr("127.0.0.1", 3443, TS_LUA_AF_INET)
    --ts.debug('route CONNECT to self: ' .. url_host)
end

-- negative_cache_disable.lua
function do_global_cache_lookup_complete()
    local cache_status = ts.http.get_cache_lookup_status()
    if cache_status == TS_LUA_CACHE_LOOKUP_HIT_FRESH then
        code = ts.cached_response.get_status()
        if 200 ~= code and 206 ~= code then
            ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_MISS)
        end
    end
end
