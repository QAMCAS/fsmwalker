#!/usr/bin/perl
use strict;
use warnings;

# Get Arguments
if (scalar @ARGV < 3) {
    print STDERR "Usage: $0 <fsm-file> <#episodes> <#steps> [seed]\n";
    exit;
}
our $fsmFilePath = $ARGV[0];
our $nEpisodes = $ARGV[1];
our $nSteps = $ARGV[2];
our $seed;
if (scalar @ARGV > 3) {
    $seed = $ARGV[3];
} else {
    $seed = 13579;
}

# Load the FSM string from file
our $fsmFile;
open ($fsmFile, "<", $fsmFilePath)
    or die "Can't open '$fsmFilePath': $!"; 
our @fsmLines = <$fsmFile>;
our $fsmString = "@fsmLines";
close $fsmFile;

our %actions = ();
our %states = ();
our $initialState;
our %transitions = ();

# Load the FSM
for my $line (@fsmLines) {
    if ($line =~ /^\s*Reset\s*\->\s*(.+)\s*(\[.*\])*;$/) {
        # Reset -> ?
        my $name = $1;
        unless (defined $states{$name}) {
            $states{$name} = $name;
            unless (defined $transitions{$name}) {
                my %t = ();
                $transitions{$name} = \%t;
            }
        } 
        $initialState = $name;
    } elsif ($line =~ /^\s*(\S+)\s*\->\s*(\S+)\s*\[label="(.*)"\];$/) {
        # <State> -> <State> [label="..."];
        my $source = $1;
        my $sink = $2;
        my $action = $3;
        $action =~ s/\\l/_/g;
        $action =~ s/_+$//g;
        unless ($action eq "else" or
                $action eq "") {
            $actions{$action} = "";
        }
        unless (defined $states{$source}) {
            $states{$source} = $source;
            unless (defined $transitions{$source}) {
                my %t = ();
                $transitions{$source} = \%t;
            }
        }
        unless (defined $states{$sink}) {
            $states{$sink} = $sink;
            unless (defined $transitions{$sink}) {
                my %t = ();
                $transitions{$sink} = \%t;
            }
        }
        unless (defined $transitions{$source}) {
            my %t = ();
            $transitions{$source} = \%t;
        }
        $transitions{$source}->{$action} = $sink;
    } elsif ($line =~ /^\s*(\S+)\s*\[label="(.*)"\];$/) {
        # <State> [label="..."];
        my $name = $1;
        my $label = $2;
        $label =~ s/\\l/_/g;
        $label =~ s/_+$//g;
        $states{$name} = $label;
        unless (defined $transitions{$name}) {
            my %t = ();
            $transitions{$name} = \%t;
        }
    }
}

# Expand 'else' and ''
for my $source (sort keys %states) {
    if (defined $transitions{$source}->{"else"}) {
        my $sink = $transitions{$source}->{"else"};
        for my $action (sort keys %actions) {
            next if (defined $transitions{$source}->{$action});
            $transitions{$source}->{$action} = $sink;
        }
        delete $transitions{$source}->{"else"};
    } elsif (defined $transitions{$source}->{""}) {
        my $sink = $transitions{$source}->{""};
        for my $action (sort keys %actions) {
            $transitions{$source}->{$action} = $sink;
        }
        delete $transitions{$source}->{""};
    }
}

# Random walk
my @actionChoices = sort keys %actions;
srand($seed);

for my $episodeId (1..$nEpisodes) {
    my $state = $initialState;
    my $stateLabel = $states{$initialState};
    print "$stateLabel\n";
    for my $stepId (1..$nSteps) {
        my $action = @actionChoices[rand(scalar @actionChoices)];
        $state = $transitions{$state}->{$action};
        $stateLabel = $states{$state};
        print "..\n$action\n$stateLabel\n";
    }
    print "--\n" unless ($episodeId == $nEpisodes);
}

