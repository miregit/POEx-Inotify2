package POEx::Inotify2;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Linux::Inotify2;
use POE;
use Carp;

=head1 NAME

POEx::Inotify2 - Monitors a directory for events using POE and Linux::Inotify2

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

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
    print "test dirs: @test_dirs\n";

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

=head1 SUBROUTINES/METHODS

=head2 new

just creates an object

=cut

sub new {
    my $this = shift;
    my %p = @_;

    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    $self->{'_p'} = \%p;

    return $self;
}

=head2 spawn

spawns a session with a specified alias

=cut

sub spawn {
    my $self = shift;
    my ($alias) = @_;
    $alias = ''
        unless defined $alias;

    my $session_id =  POE::Session->create(
        'inline_states' => {
            '_start' => sub {
                my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
                @$heap{'self', 'alias'} = @_[ARG0..$#_];

                $kernel->alias_set( $heap->{'alias'} )
                    if (defined $heap->{'alias'} and length $heap->{'alias'});
                $heap->{'in2'} = new Linux::Inotify2 or
                    croak "Unable to create Linux::Inotify2 object: $!";
                $heap->{'in2'}->blocking(0);
                open $heap->{'fh_inotify'}, "< &=" . $heap->{'in2'}->fileno or
                    croak "Can’t fdopen: $!";
                $kernel->select_read($heap->{'fh_inotify'}, 'poll');
                $heap->{'o'} = {};
            },
            'add' => sub {
                my ($kernel, $heap, $session, $dir, $mask, $cb) = @_[KERNEL, HEAP, SESSION, ARG0..$#_];
                my $o = $heap->{'o'};
                my $watch = $heap->{'in2'}->watch($dir, $mask, $cb) or
                    croak "Unable to watch $dir: $!";
                $o->{$dir} = $watch;
            },
            'add_dir' => sub {
                my ($kernel, $heap, $session, $dir, $mask, $cb, $user) = @_[KERNEL, HEAP, SESSION, ARG0..$#_];
                $main::eu->check_create_dir($dir, $user);
                my $o = $heap->{'o'};
                my $watch = $heap->{'in2'}->watch($dir, $mask, $cb) or
                    croak "Unable to watch $dir: $!";
                $o->{$dir} = $watch;
            },
            'poll' => sub {
                $_[HEAP]->{'in2'}->poll;
            },
            'remove' => sub {
                my ($kernel, $heap, $session, $dir) = @_[KERNEL, HEAP, SESSION, ARG0..$#_];
                return
                    unless exists $heap->{'o'}->{$dir};
                $heap->{'o'}->{$dir}->cancel;
                delete $heap->{'o'}->{$dir};
            },
            'finish' => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];
                foreach my $dir (keys %{$heap->{'o'}}) {
                    $heap->{'o'}->{$dir}->cancel
                        if exists $heap->{'o'}->{$dir};
                }
                $heap->{'o'} = {};
                $kernel->select_read($heap->{'fh_inotify'});
                delete $heap->{'fh_inotify'};
                delete $heap->{'in2'};
                $kernel->alias_remove($heap->{'alias'});
            },
      },
      'args' => [$self, $alias],
)->ID;
    return $session_id;
}

=head1 AUTHOR

Miroslav Madzarevic

=head1 BUGS

Maybe ;)

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Miroslav Madzarevic.

=cut

1; # End of POEx::Inotify2
