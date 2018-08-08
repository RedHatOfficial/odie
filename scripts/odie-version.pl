#!/bin/perl

use IO::Handle;

my @flags = ( 'stage', 'patch', 'install', 'configure', 'properties', 'harden', 'content');
my %properties = {};

my $semver = "/opt/odie/src/contrib/bin/semver";
my $property_file = "/etc/odie-release";

my $mode = shift;
my $flag = shift;
my $ver = shift;

# this is used for 0.6.0.1 build that didnt have the multi-line format
my $global;

if (-s $property_file) {
  open(VERSION, $property_file) or die "FATAL: Can't open file ($property_file): $!";
  for $file_version (<VERSION>) {
    chomp($file_version);
    $file_version =~ /(\w+): (.*)$/;
    if ( defined $1 )  {
      $properties{$1}=$2;
    }
    else {
      $properties{$_} = $file_version foreach @flags;
    }
  }
  close(VERSION);
}
else {
  $properties{$_} = "0.0.0" foreach @flags;
}

sub output_properties($$) {
  my $flag = shift;
  my $ver = shift;
  for (@flags) {
    if (defined $flag && not defined $ver) {
      next if not /$flag/;
    }
    else {
      print "$_: ";
    }
    my $v = $properties{$_};
    print "$v\n";
  }
}

sub check_version($$) {
  my $lflag = shift;
  my $rflag = shift;
  my $left = $properties{$lflag};
  my $right = $properties{$rflag};
  return `$semver compare $left $right`;
}

# get the effective version if we use active
if ($flag =~ /active/) {
  $flag = (&check_version('install', 'patch') >= 0) ? 'install' : 'patch';
}

if ($mode =~ /set/) {
  $properties{$flag} = $ver if defined $flag and defined $ver;
  open(OUTPUT, '>', $property_file) or die "FATAL: Can't open file ($property_file): $!";
  STDOUT->fdopen( \*OUTPUT, 'w') or die $!;
  &output_properties();

}
elsif ($mode =~ /show/) {
  &output_properties($flag);
}
elsif ($mode =~ /compare/) {
  # overloading the stdargs because its perl and I'm lazy
  print &check_version($flag, $ver);
}
