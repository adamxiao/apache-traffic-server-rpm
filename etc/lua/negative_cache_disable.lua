function do_global_cache_lookup_complete()
    local cache_status = ts.http.get_cache_lookup_status()
    if cache_status == TS_LUA_CACHE_LOOKUP_HIT_FRESH then
        code = ts.cached_response.get_status()
        if 200 ~= code and 206 ~= code then
            ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_MISS)
        end
    end
end
