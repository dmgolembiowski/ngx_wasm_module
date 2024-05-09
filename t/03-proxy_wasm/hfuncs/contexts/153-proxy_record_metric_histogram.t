# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

skip_hup();

our $workers = 2;

workers($workers);
if ($workers > 1) {
    master_on();
}

plan_tests(7);
run_tests();

__DATA__

=== TEST 1: proxy_wasm metrics shm - record_metric, histogram - sanity
--- skip_no_debug
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config eval
my $filters;

foreach my $exp (0 .. 17) {
    my $v = 2 ** $exp;
    $filters .= "
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              test=/t/metrics/record_histograms \
                              metrics=h1 \
                              value=$v';";
}
qq{
    location /t {
        $filters

        echo ok;
    }
}
--- error_log eval
[
    "growing histogram",
    qr/histogram "\d+": 1: 1; 2: 1; 4: 1; 8: 1; 16: 1; 32: 1; 64: 1; 128: 1; 256: 1; 512: 1; 1024: 1; 2048: 1; 4096: 1; 8192: 1; 16384: 1; 32768: 1; 65536: 1; 4294967295: 1;/
]
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 2: proxy_wasm metrics shm - record_metric, histogram - on_configure
--- skip_no_debug
--- workers: 2
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on_configure=define_and_record_histograms \
                              test=/t/metrics/record_histograms \
                              metrics=h1 \
                              value=10';
        echo ok;
    }
--- grep_error_log eval: qr/histogram "\d+":( \d+: \d+;)+/
--- grep_error_log_out eval
qr/histogram "\d+": 16: $::workers; 4294967295: 0;/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
[stub]



=== TEST 3: proxy_wasm metrics - record_metric(), histogram - on_tick
--- skip_no_debug
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- config eval
my $filters;

foreach my $wid (0 .. $::workers - 1) {
    $filters .= "
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on_tick=record_histograms \
                              tick_period=100 \
                              n_sync_calls=1 \
                              on_worker=$wid \
                              value=1 \
                              metrics=h2';";
}
qq{
    location /t {
        $filters

        echo ok;
    }
}
--- grep_error_log eval: qr/histogram "\d+":( \d+: \d+;)+/
--- grep_error_log_out eval
qr/histogram "\d+": 1: $::workers; 4294967295: 0;/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
[stub]



=== TEST 4: proxy_wasm metrics - record_metric(), histogram - on: request_headers, request_body, response_headers, response_body
--- skip_no_debug
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config eval
my $phases = CORE::join(',', qw(
    request_headers
    request_body
    response_headers
    response_body
));

qq{
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=$phases \
                              test=/t/metrics/record_histograms \
                              value=100 \
                              metrics=h1';
        echo ok;
    }
}
--- request
POST /t
hello
--- grep_error_log eval: qr/histogram "\d+":( \d+: \d+;)+/
--- grep_error_log_out eval
qr/histogram "\d+": 128: 4; 4294967295: 0;/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
[stub]



=== TEST 5: proxy_wasm metrics - record_metric(), histogram - on_http_call_response
--- skip_no_debug
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- http_config eval
--- config eval
qq{
    listen unix:$ENV{TEST_NGINX_UNIX_SOCKET};

    location /dispatched {
        return 200 "Hello back";
    }

    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              test=/t/dispatch_http_call \
                              host=unix:$ENV{TEST_NGINX_UNIX_SOCKET} \
                              path=/dispatched \
                              on_http_call_response=record_histograms \
                              value=1000 \
                              metrics=h2';
        echo ok;
    }
}
--- grep_error_log eval: qr/histogram "\d+":( \d+: \d+;)+/
--- grep_error_log_out eval
qr/histogram "\d+": 1024: 1; 4294967295: 0;/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
[stub]
