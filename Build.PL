
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'Module::Build' => '0.3601',
    'Test::Distribution' => '0',
    'Test::More' => '0',
    'perl' => '5.8.5'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'report on and update an SQLite database.',
  'dist_author' => [
    'Kathryn Andersen'
  ],
  'dist_name' => 'SQLite-Work',
  'dist_version' => '0.11',
  'license' => 'perl',
  'module_name' => 'SQLite::Work',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'CGI' => '0',
    'DBI' => '0',
    'Data::Dumper' => '0',
    'File::Temp' => '0',
    'Getopt::ArgvFile' => '0',
    'Getopt::Long' => '2.34',
    'POSIX' => '0',
    'Pod::Usage' => '0',
    'Text::NeatTemplate' => '0'
  },
  'script_files' => [
    'scripts/sqlw_import',
    'scripts/sqlreport',
    'scripts/sqlw_mail'
  ]
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
