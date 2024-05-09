# vim:set ft= ts=4 sts=4 sw=4 et fdm=marker:

use strict;
use lib '.';
use t::TestWasmX;

our $workers = 2;

workers($workers);
if ($workers > 1) {
    master_on();
}

plan_tests(6);
run_tests();

__DATA__

=== TEST 1: proxy_wasm contexts - proxy_define_metric - on_vm_start
Hostcalls filter prefixes the name of a metric with the phase in which it's
defined. A metric c1 defined within on_configure ends up named c1_Configure.

--- skip_no_debug
--- valgrind
--- main_config
    wasm {
        module hostcalls $TEST_NGINX_CRATES_DIR/hostcalls.wasm 'define_metric';
    }
--- config
    location /t {
        proxy_wasm hostcalls;
        return 200;
    }
--- error_log eval
qr/defined counter ".+c1_OnVMStart" with id \d+/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 2: proxy_wasm contexts - proxy_define_metric - on_configure
--- valgrind
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- config
    location /t {
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              metrics=c1,g1';
        echo ok;
    }
--- grep_error_log eval: qr/defined metric \w+ as \d+ at \w+/
--- grep_error_log_out eval
qr/defined metric c1_Configure as \d+ at Configure
defined metric g1_Configure as \d+ at Configure\n/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 3: proxy_wasm contexts - proxy_define_metric - on_tick
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- config
    location /t {
        proxy_wasm hostcalls 'on_tick=define_metrics \
                              tick_period=500 \
                              n_sync_calls=1 \
                              metrics=c1,g1';
        echo ok;
    }
--- grep_error_log eval: qr/defined metric \w+ as \d+ at \w+/
--- grep_error_log_out eval
qr/defined metric c1_Tick as \d+ at Tick
defined metric g1_Tick as \d+ at Tick\n/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 4: proxy_wasm contexts - proxy_define_metric - on: request_headers, request_body, response_headers, response_body, log
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
        proxy_wasm hostcalls 'on=$phases \
                              test=/t/metrics/define \
                              metrics=c1,g1';
        echo ok;
    }
}
--- request
POST /t
hello
--- grep_error_log eval: qr/defined metric \w+ as \d+ at \w+/
--- grep_error_log_out eval
my $checks;
my @phases = qw(
    RequestHeaders
    RequestBody
    ResponseHeaders
    ResponseBody
    ResponseBody
    Log
);

foreach my $p (@phases) {
     my $suffixed_c1 = "c1_" . $p;
     my $suffixed_g1 = "g1_" . $p;
     $checks .= "
?defined metric $suffixed_c1 as [0-9]+ at $p
defined metric $suffixed_g1 as [0-9]+ at $p\n";
}

qr/$checks/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 5: proxy_wasm contexts - proxy_define_metric - on_http_call_response
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
        proxy_wasm hostcalls 'test=/t/dispatch_http_call \
                              host=unix:$ENV{TEST_NGINX_UNIX_SOCKET} \
                              path=/dispatched \
                              on_http_call_response=define_metrics \
                              metrics=c1,g1';
        echo ok;
    }
}
--- grep_error_log eval: qr/defined metric \w+ as \d+ at \w+/
--- grep_error_log_out eval
qr/defined metric c1_HTTPCallResponse as \d+ at HTTPCallResponse
defined metric g1_HTTPCallResponse as \d+ at HTTPCallResponse\n/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
