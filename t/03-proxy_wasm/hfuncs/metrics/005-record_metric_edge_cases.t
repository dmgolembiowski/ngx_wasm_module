# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

skip_hup();
no_shuffle();

plan_tests(4);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics - record_metric() no memory, can't expand histogram
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
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/record_histograms \
                              metrics=h16256 \
                              value=1 \
                              metrics_name_len=115';

        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/record_histograms \
                              metrics=h16256 \
                              value=2 \
                              metrics_name_len=115';

        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/record_histograms \
                              metrics=h16256 \
                              value=4 \
                              metrics_name_len=115';

        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/record_histograms \
                              metrics=h16256 \
                              value=8 \
                              metrics_name_len=115';

        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=request_headers \
                              test=/t/metrics/record_histograms \
                              metrics=h16256 \
                              value=16 \
                              metrics_name_len=115';
        echo ok;
    }
--- error_log
cannot expand histogram
--- no_error_log
[emerg]
[alert]
