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

=== TEST 1: proxy_wasm contexts - proxy_record_metric - on_vm_start
--- skip_no_debug
--- valgrind
--- main_config
    wasm {
        module hostcalls $TEST_NGINX_CRATES_DIR/hostcalls.wasm 'record_metric';
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



=== TEST 2: proxy_wasm metrics shm - proxy_record_metric - on_configure
--- workers: 1
--- valgrind
--- load_nginx_modules: ngx_http_echo_module
--- wasm_modules: hostcalls
--- config
    location /t {
        proxy_wasm hostcalls 'metrics=g2 \
                              on_configure=define_and_toggle_gauges';
        echo ok;
    }
--- grep_error_log eval: qr/(toggled \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
my $check;
$check .= "toggled g1_Configure at Configure(\n|\n.+\n)";
$check .= "toggled g2_Configure at Configure(\n|\n.+\n)";
$check .= "g1_Configure: 1 at Configure(\n|\n.+\n)";
$check .= "g2_Configure: 1 at Configure(\n|\n.+\n)";
qr/$check/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 3: proxy_wasm metrics - proxy_record_metric - on_tick
--- wasm_modules: hostcalls
--- load_nginx_modules: ngx_http_echo_module
--- config eval
my $filters;

foreach my $wid (0 .. $::workers - 1) {
    my $wait = 100 + ($wid * 500);
    $filters .= "
        proxy_wasm hostcalls 'on_configure=define_metrics \
                              on_tick=set_gauges \
                              tick_period=$wait \
                              n_sync_calls=1 \
                              on_worker=$wid \
                              value=$wid \
                              metrics=g2';";
}
qq{
    location /t {
        $filters

        echo ok;
    }
}
--- wait: 1
--- grep_error_log eval: qr/(record \d+ on \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
my $checks;

foreach my $worker_id (0 .. $::workers - 1) {
    $checks .= "record $worker_id on g1_Configure at Tick
record $worker_id on g2_Configure at Tick
g1_Configure: $worker_id at Tick
g2_Configure: $worker_id at Tick
";
}

qr/$checks/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 4: proxy_wasm metrics - proxy_record_metric - on: request_headers, request_body, response_headers, response_body, log
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
                              test=/t/metrics/toggle_gauges \
                              metrics=g2';
        echo ok;
    }
}
--- request
POST /t
hello
--- grep_error_log eval: qr/(toggled \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
my $i = 0;
my $checks;
my @phases = qw(
    RequestHeaders
    RequestBody
    ResponseHeaders
    ResponseBody
    ResponseBody
    Log
);

foreach my $phase (@phases) {
    $i = $i ? 0 : 1;
    $checks .= "
?toggled g1_Configure at $phase
toggled g2_Configure at $phase
g1_Configure: $i at $phase
g2_Configure: $i at $phase\n";
}

qr/$checks/
--- no_error_log
[error]
[crit]
[emerg]
[alert]



=== TEST 5: proxy_wasm metrics - proxy_record_metric - on_http_call_response
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
                              on_http_call_response=toggle_gauges \
                              metrics=g2';
        echo ok;
    }
}
--- grep_error_log eval: qr/(toggled \w+|\w+: \d+) at \w+/
--- grep_error_log_out eval
qr/toggled g1_Configure at HTTPCallResponse
toggled g2_Configure at HTTPCallResponse
g1_Configure: 1 at HTTPCallResponse
g2_Configure: 1 at HTTPCallResponse\n/
--- no_error_log
[error]
[crit]
[emerg]
[alert]
