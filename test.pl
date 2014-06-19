#!/usr/bin/perl -w
use strict;
use warnings;
use POEx::Inotify2;
use Linux::Inotify2; # for constants
use POE;
use File::Temp ('tempdir');
use IO::File;
use Carp;
use File::Basename;

my @test_dirs = (tempdir( CLEANUP => 1 ), tempdir( CLEANUP => 1 ));
print 
    "test dirs: @test_dirs\n" .
    "code should detect 4 new files below\n";

my $test_sid = POE::Session->create(
    inline_states => {
        _start => sub {
            my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
            POEx::Inotify2->new()->spawn('i2');
            foreach my $dp (@test_dirs) {
                $kernel->post('i2', 'add', $dp, IN_CLOSE_WRITE, $session->postback('watch_handler'));
            }
            $kernel->yield('make_some_files');
            $kernel->yield('finish');
        },
        make_some_files => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            foreach my $fn (qw|a.txt q.txt|) {
                foreach my $dp (@test_dirs) {
                    my $fh = IO::File->new("$dp/$fn", '>');
                    if (defined $fh) {
                        print $fh "test\n";
                        $fh->close;
                    } else {
                        croak "ERROR: can not create $dp/$fn $!\n";
                    }
                }
            }
        },
        watch_handler => sub {
            my $e = $_[ARG1][0];
            my $fp = $e->fullname;
            print "we got new file $fp\n" 
                if $e->IN_CLOSE_WRITE;
            if (basename $fp eq 'q.txt') {
                my $dp = dirname($fp);
                $_[KERNEL]->post('i2', 'remove', $dp);
            }
        },
        finish => sub {
            $_[KERNEL]->post('i2', 'finish');
        },
    },
);

POE::Kernel->run();
exit;

