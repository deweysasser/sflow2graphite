#!/usr/bin/perl -w
use strict;
use POSIX;
use IO::Socket::INET;
use Getopt::Std;

my %opt;
getopts('hds:p:', \%opt);

usage() if $opt{h};

my $graphite_server = $opt{s} || '127.0.0.1';
my $graphite_port   = $opt{p} || 2003;

my %metricNames = (
 "cpu_load_one"            => "load.load_one",
 "cpu_load_five"           => "load.load_five",
 "cpu_load_fifteen"        => "load.load_fifteen",
 "disk_total"              => "disk.total",
 "disk_free"               => "disk.free",
 "disk_partition_max_used" => "disk.part_max",
 "disk_reads"              => "disk.reads",
 "disk_bytes_read"         => "disk.bytes_read",
 "disk_read_time"          => "disk.read_time",
 "disk_writes"             => "disk.writes",
 "disk_bytes_written"      => "disk.bytes_written",
 "disk_write_time"         => "disk.write_time",
 "mem_total"               => "mem.total",
 "mem_free"                => "mem.free",
 "mem_shared"              => "mem.shared",
 "mem_buffers"             => "mem.buffers",
 "mem_cached"              => "mem.cached",
 "swap_total"              => "mem.swap_total",
 "swap_free"               => "mem.swap_free",
 "page_in"                 => "mem.page_in",
 "page_out"                => "mem.page_out",
 "swap_in"                 => "mem.swap_in",
 "swap_out"                => "mem.swap_out",
 "cpu_proc_run"            => "cpu.proc_run",
 "cpu_proc_total"          => "cpu.proc_total",
 "cpu_num"                 => "cpu.num",
 "cpu_speed"               => "cpu.speed",
 "cpu_uptime"              => "cpu.uptime",
 "cpu_user"                => "cpu.user",
 "cpu_nice"                => "cpu.nice",
 "cpu_system"              => "cpu.system",
 "cpu_idle"                => "cpu.idle",
 "cpu_wio"                 => "cpu.wio",
 "cpuintr"                 => "cpu.intr",
 "cpu_sintr"               => "cpu.sintr",
 "cpuinterrupts"           => "cpu.interrupts",
 "cpu_contexts"            => "cpu.contexts",
 "nio_bytes_in"            => "net.bytes_in",
 "nio_pkts_in"             => "net.pkts_in",
 "nio_errs_in"             => "net.errs_in",
 "nio_drops_in"            => "net.drops_in",
 "nio_bytes_out"           => "net.bytes_out",
 "nio_pkts_out"            => "net.pkts_out",
 "nio_errs_out"            => "net.errs_out",
 "nio_drops_out"           => "net.drops_out",
 "http_method_option_count"=> "http.method_option",
 "http_method_get_count"   => "http.method_get",
 "http_method_head_count"  => "http.method_head",
 "http_method_post_count"  => "http.method_post",
 "http_method_put_count"   => "http.method_put",
 "http_method_delete_count"=> "http.method_delete",
 "http_method_trace_count" => "http.method_trace",
 "http_methd_connect_count"=> "http.method_connect",
 "http_method_other_count" => "http.method_other",
 "http_status_1XX_count"   => "http.status_1XX",
 "http_status_2XX_count"   => "http.status_2XX",
 "http_status_3XX_count"   => "http.status_3XX",
 "http_status_4XX_count"   => "http.status_4XX",
 "http_status_5XX_count"   => "http.status_5XX",
 "http_status_other_count" => "http.status_other",
 "heap_mem_initial"        => "jvm.heap_initial",
 "heap_mem_used"           => "jvm.heap_used",
 "heap_mem_committed"      => "jvm.heap_committed",
 "heap_mem_max"            => "jvm.heap_max",
 "non_heap_mem_initial"    => "jvm.non_heap_initial",
 "non_heap_mem_used"       => "jvm.non_heap_used",
 "non_heap_mem_committed"  => "jvm.non_heap_committed",
 "non_heap_mem_max"        => "jvm.non_heap_max",
 "gc_count"                => "jvm.gc_count",
 "gc_mS"                   => "jvm.gc_mS",
 "classes_loaded"          => "jvm.classes_loaded",
 "classes_total"           => "jvm.classes_total",
 "classes_unloaded"        => "jvm.classes_unloaded",
 "compilation_mS"          => "jvm.compilation_mS",
 "threads_live"            => "jvm.threads_live",
 "threads_daemon"          => "jvm.threads_daemon",
 "threads_started"         => "jvm.threads_started",
 "fds_open"                => "jvm.fds_open",
 "fds_max"                 => "jvm.fds_max"
);

&daemonize if $opt{d};

my $sock = IO::Socket::INET->new(
       PeerAddr => $graphite_server,
       PeerPort => $graphite_port,
       Proto    => 'tcp'
    );

die "Unable to connect: $!\n" unless ($sock->connected);

open(PS, "/usr/local/bin/sflowtool |") || die "Failed: $!\n";

my $agentIP = "";
my $sourceId = "";
my $now = "";
my $attr = "";
my $value = "";
my %hostNames = ();
while( <PS> ) {
  ($attr,$value) = split;
  if('startDatagram' eq $attr) {
    $now = time;
  } elsif ('agent' eq $attr) {
    $agentIP = $value;
  } elsif ('sourceId' eq $attr) {
    $sourceId = $value;
  } elsif ('hostname' eq $attr) {
    if($sourceId eq "2:1") {
      my ($hn) = split /[.]/, $value;
      $hostNames{$agentIP} = $hn;
    }
  } else {
    my $metric = $metricNames {$attr};
    my $hostName = $hostNames{$agentIP};
    if($metric && $hostName) {
        $sock->send("$hostName.$metric $value $now\n");
    }
  }
}

$sock->shutdown(2);

sub signalHandler {
  close(PS);
}

sub usage {
  print <<EOF;
  usage: $0 [-hd] [-s server] [-p port]
    -h        : this (help) message
    -d        : daemonize
    -s server : graphite server (default 127.0.0.1)
    -p port   : graphite port   (default 2003)
  example: $0 -d -s 10.0.0.151 -p 2004
EOF
  exit;
}

sub daemonize {
   POSIX::setsid or die "setsid: $!";
   my $pid = fork();
   if($pid < 0) {
      die "fork: $!";
   } elsif ($pid) {
      exit 0;
   }
   chdir "/";
   umask 0;
   foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
      { POSIX::close $_ }
   open(STDIN, "</dev/null");
   open(STDOUT, ">/dev/null");
   open(STDERR, ">&STDOUT");

   $SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
   $SIG{PIPE} = 'ignore';
}

