# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

plan_tests(7);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics - record_metric() counter
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/toggle_counters \
                              metrics=c1,c2';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    qr/\[error\] .+ \[wasm\] attempt to call record_metric on a counter; operation not supported/,
    qr/.+on_request_headers.+/,
    qr/host trap \(internal error\): could not record metric.*/,
]
--- no_error_log
[crit]
[emerg]
[alert]



=== TEST 2: proxy_wasm metrics - record_metric() invalid metric id
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/set_invalid_gauge';
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
