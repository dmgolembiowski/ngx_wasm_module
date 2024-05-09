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

plan_tests(6);
run_tests();

__DATA__

=== TEST 1: proxy_wasm contexts - proxy_increment_metric - on_vm_start
--- skip_no_debug
--- valgrind
--- main_config
    wasm {
        module hostcalls $TEST_NGINX_CRATES_DIR/hostcalls.wasm 'increment_metric';
    }
--- config
    location /t {
        proxy_wasm hostcalls;
        return 200;
    }
--- error_log eval
qr/updating metric "\d+" with 1/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 2: proxy_wasm metrics shm - proxy_increment_metric - on_configure
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'on_configure=define_and_increment_counters \
                              metrics=c2';
        echo ok;
    }
--- error_log eval
qr/c1_Configure: $::workers at Configure/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 3: proxy_wasm metrics - proxy_increment_metric() - on_tick
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- config
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on_tick=increment_counters \
                              tick_period=500 \
                              n_sync_calls=1 \
                              metrics=c2';
        echo ok;
    }
--- error_log eval
qr/c1_Configure: $::workers at Tick/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 4: proxy_wasm metrics - proxy_increment_metric() - on: request_headers, request_body, response_headers, response_body, log
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config eval
my $phases = CORE::join(',', qw(
    request_headers
    request_body
    response_headers
    response_body
    log
));

qq{
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on=$phases \
                              test=/t/metrics/increment_counters \
                              metrics=c2';
        echo ok;
    }
}
--- request
POST /t
hello
--- grep_error_log eval: qr/(incremented \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
my $checks;
my $i = 0;
my @phases = qw(
    RequestHeaders
    RequestBody
    ResponseHeaders
    ResponseBody
    ResponseBody
    Log
);

foreach my $p (@phases) {
    $i++;
    $checks .= "
?incremented c1_Configure at $p
incremented c2_Configure at $p
c1_Configure: $i at $p
c2_Configure: $i at $p\n";
}

qr/$checks/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 5: proxy_wasm metrics - proxy_increment_metric() - on_http_call_response
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
                              on_http_call_response=increment_counters \
                              metrics=c2';
        echo ok;
    }
}
--- grep_error_log eval: qr/(incremented \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
qr/incremented c1_Configure at HTTPCallResponse
incremented c2_Configure at HTTPCallResponse
c1_Configure: 1 at HTTPCallResponse
c2_Configure: 1 at HTTPCallResponse\n/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
