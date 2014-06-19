use 5.018002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'POEx::Inotify2',
    VERSION_FROM      => 'lib/POEx/Inotify2.pm', # finds $VERSION
    PREREQ_PM         => {
        'Linux::Inotify2' => 0,
        'POE' => 0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/POEx/Inotify2.pm', # retrieve abstract from module
       AUTHOR         => 'Magyarevity Miroszlav <githubcode@osadmin.com>') : ()),
);
