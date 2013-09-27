use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use File::Find;
use File::Spec;
use Path::Tiny;
use Module::Runtime 'use_module';
use List::MoreUtils 'none';

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe', 'PromptIfStale' ],
                        installer => 'MakeMaker',
                      },
                    ],
                ),
                path(qw(source lib MyDist.pm)) => 'package MyDist; 1',
            },
        },
    );

    $tzil->build;

    my $build_dir = $tzil->tempdir->subdir('build');
    my @found_files;
    find({
            wanted => sub { push @found_files, File::Spec->abs2rel($_, $build_dir) if -f  },
            no_chdir => 1,
         },
        $build_dir,
    );

    cmp_deeply(
        \@found_files,
        all(
            superbagof('Makefile.PL'),
            code(sub { none { $_ eq 'Build.PL' } @{$_[0]} }),
        ),
        'Makefile.PL (and no other build file) was generated by the pluginbundle',
    );
}

SKIP: {
    # MBT is already in our runtime recommends list
    skip('[ModuleBuildTiny] not installed', 1)
        if not eval { use_module 'Dist::Zilla::Plugin::ModuleBuildTiny'; 1 };

    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe', 'PromptIfStale' ],
                        installer => [ qw(MakeMaker ModuleBuildTiny) ],
                      },
                    ],
                ),
                path(qw(source lib MyModule.pm)) => 'package MyModule; 1',
            },
        },
    );

    $tzil->build;

    my $build_dir = $tzil->tempdir->subdir('build');
    my @found_files;
    find({
            wanted => sub { push @found_files, File::Spec->abs2rel($_, $build_dir) if -f  },
            no_chdir => 1,
         },
        $build_dir,
    );

    cmp_deeply(
        \@found_files,
        superbagof(qw(
            Makefile.PL
            Build.PL
        )),
        'both Makefile.PL and Build.PL were generated by the pluginbundle',
    );
}

done_testing;
