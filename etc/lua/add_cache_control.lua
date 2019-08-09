function read_response()
    local status_code = ts.server_response.get_status()
    local cache_control = ts.server_response.header['Cache-Control']

    -- Cache 200/206 responses for 10 days
    if status_code == 200 or status_code == 206 then
        ts.server_response.header['Cache-Control'] = 'max-age=864000'
    end
end

function do_remap()
    ts.hook(TS_LUA_HOOK_READ_RESPONSE_HDR, read_response)
    return 0
end
