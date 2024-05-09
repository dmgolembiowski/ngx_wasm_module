# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

plan_tests(7);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics - increment_metric() gauge
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config eval
qq{
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/increment_gauges \
                              metrics=g1,g2';
        echo ok;
    }
}
--- error_code: 500
--- error_log eval
[
    qr/\[error\] .+ \[wasm\] attempt to call increment_metric on a gauge; operation not supported/,
    qr/.+on_request_headers.+/,
    qr/host trap \(internal error\): could not increment metric.*/,
]
--- no_error_log
[crit]
[emerg]
[alert]



=== TEST 2: proxy_wasm metrics - increment_metric() invalid metric id
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/increment_invalid_counter';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    qr/.+on_request_headers.+/,
    qr/metric \"\d+\" not found.*/,
    qr/host trap \(internal error\): could not increment metric.*/,
]
--- no_error_log
[crit]
[emerg]
[alert]
