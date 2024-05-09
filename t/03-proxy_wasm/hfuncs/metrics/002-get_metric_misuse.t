# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

plan_tests(7);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics - get_metric() invalid metric id
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/get_invalid_metric';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    qr/.+on_request_headers.+/,
    qr/metric \"0\" not found.*/,
]
--- no_error_log
[crit]
[emerg]
[alert]
[stub]
