# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

skip_hup();
no_shuffle();

plan_tests(6);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics - define_metric() metric name too long
In SIGHUP mode, this test fails if executed after a test that defined metrics,
as any existing metric whose name exceeds `max_metric_name_length` won't be
successfully reallocated causing the reconfiguration to fail.

--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- main_config eval
qq{
    wasm {
        module hostcalls $ENV{TEST_NGINX_CRATES_DIR}/hostcalls.wasm;

        metrics {
            max_metric_name_length 4;
        }
    }
}
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/define \
                              metrics=c1';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    qr/.+on_request_headers.+/,
    qr/host trap \(internal error\): metric name too long.*/,
]
--- no_error_log
[emerg]
[alert]
[stub]



=== TEST 2: proxy_wasm metrics - define_metric() no memory
In SIGHUP mode, this test fails if executed after a test that defined more
metrics than it's possible to fit in `5m`.

--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- main_config eval
qq{
    wasm {
        module hostcalls $ENV{TEST_NGINX_CRATES_DIR}/hostcalls.wasm;

        metrics {
            slab_size 5m;
            max_metric_name_length 128;
        }
    }
}
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/define \
                              metrics=c20337 \
                              metrics_name_len=100';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    qr/\[crit\] .+ \[wasm\] "metrics" shm store: no memory; cannot allocate pair with key size \d+ and value size \d+/,
    qr/.+on_request_headers.+/,
    qr/host trap \(internal error\): could not define metric.*/,
]
--- no_error_log
[emerg]
[alert]



=== TEST 3: proxy_wasm metrics - define_metric() no memory, histogram
In SIGHUP mode, this test fails if executed after a test that defined more
metrics than it's possible to fit in `5m`.

--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- main_config eval
qq{
    wasm {
        module hostcalls $ENV{TEST_NGINX_CRATES_DIR}/hostcalls.wasm;

        metrics {
            slab_size 16k;
            max_metric_name_length 128;
        }
    }
}
--- config
    location /t {
        proxy_wasm hostcalls 'on=request_headers \
                              test=/t/metrics/define \
                              metrics=c30,h16';
        echo ok;
    }
--- error_code: 500
--- error_log eval
[
    "cannot allocate histogram",
    qr/.+on_request_headers.+/,
    qr/host trap \(internal error\): could not define metric.*/,
]
--- no_error_log
[emerg]
[alert]
