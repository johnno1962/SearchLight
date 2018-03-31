#!/usr/bin/perl -w

use strict;
use IO::File;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

my $cgi = CGI->new();
my $hash = $cgi->param("hash");

my $dir = "../../../searchlight/".substr($hash, 0, 4);
my $name = substr($hash, 4);
my $path = "$dir/$name";

print $cgi->header();

if (!-f $path) {
    my $seal = 283746511;
    for (my $i=0; $i<length $hash; $i++) {
        $seal += ord(substr($hash, $i, 1))*23;
    }
    mkdir $dir or die "$dir - $!";
    IO::File->new(">$path")->print(sprintf("%d %d %d", $seal, time()+2*7*24*60*60, time()+0));
}

print(IO::File->new($path)->getline());
