#!/usr/bin/perl
use strict;
use warnings;

# Get Arguments
if (scalar @ARGV < 1) {
    print STDERR "Usage: $0 <fsm-file>\n";
    exit;
}
our $fsmFilePath = $ARGV[0];
our $mutantPath = "mutants";
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

# MUTATIONS:
#
# Important for us
# ----------------
# RG: Reset Glitch
# SF: Stuck-at Fault
# TG: Transition Glitch
# WO: Waits-Once
#
# Not important for us
# --------------------
# IG/OG: Input/Output Glitch
# EG: End Glitch
# 
our $nMutants = 0;

sub mutateAndSave {
    my $mtype = shift @_;
    my $mIndex;
    if ($nMutants < 10) {
        $mIndex = "0$nMutants";
    } else {
        $mIndex = "$nMutants";
    }
    if ($mtype eq "RG") {
        my $newInitialState = shift @_;
        my $path = "${mutantPath}/mutant_${mIndex}_RG_${newInitialState}_$fsmFilePath";
        open($fsmFile, ">", $path);
        print $fsmFile "digraph \"$path\" {\n";
        print $fsmFile "    Reset [style=invis,shape=point,label=\"\",width=0,height=0];\n";
        for my $state (sort keys %states) {
            my $label = $states{$state};
            $label =~ s/_/\\l/g;
            print $fsmFile "    $state [label=\"$label\\l\"];\n";
        }
        print $fsmFile "    Reset -> $newInitialState;\n";
        for my $source (sort keys %states) {
            my $nSelfLoops = 0;
            for my $action (sort keys %actions) {
                my $sink = $transitions{$source}->{$action};
                $nSelfLoops++ if ($sink eq $source);
            }
            if ($nSelfLoops == scalar keys %actions) {
                print $fsmFile "    $source -> $source [label=\"\"];\n";
                next;
            } elsif ($nSelfLoops > 1) {
                print $fsmFile "    $source -> $source [label=\"else\"];\n";
            }
            for my $action (sort keys %actions) {
                my $sink = $transitions{$source}->{$action};
                $action =~ s/_/\\l/g;
                next if ($sink eq $source and $nSelfLoops > 1);
                print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
            }
        }
        print $fsmFile "}\n";
    } elsif ($mtype eq "SF") {
        my $stuckAtState = shift @_;
        my $path = "${mutantPath}/mutant_${mIndex}_SF_${stuckAtState}_$fsmFilePath";
        open($fsmFile, ">", $path);
        print $fsmFile "digraph \"$path\" {\n";
        print $fsmFile "    Reset [style=invis,shape=point,label=\"\",width=0,height=0];\n";
        for my $state (sort keys %states) {
            my $label = $states{$state};
            $label =~ s/_/\\l/g;
            print $fsmFile "    $state [label=\"$label\\l\"];\n";
        }
        print $fsmFile "    Reset -> $initialState;\n";
        for my $source (sort keys %states) {
            if ($source eq $stuckAtState) {
                print $fsmFile "    $source -> $source [label=\"\"];\n";
                next;
            }            
            my $nSelfLoops = 0;
            for my $action (sort keys %actions) {
                my $sink = $transitions{$source}->{$action};
                $nSelfLoops++ if ($sink eq $source);
            }
            if ($nSelfLoops == scalar keys %actions) {
                print $fsmFile "    $source -> $source [label=\"\"];\n";
                next;
            } elsif ($nSelfLoops > 1) {
                print $fsmFile "    $source -> $source [label=\"else\"];\n";
            }
            for my $action (sort keys %actions) {
                my $sink = $transitions{$source}->{$action};
                $action =~ s/_/\\l/g;
                next if ($sink eq $source and $nSelfLoops > 1);
                print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
            }
        }
        print $fsmFile "}\n";
    } elsif ($mtype eq "TG") {
        my ($glitchSource, $glitchedAction, $glitchResult) = @_;
        my $path = "${mutantPath}/mutant_${mIndex}_TG_${glitchSource}_$fsmFilePath";
        open($fsmFile, ">", $path);
        print $fsmFile "digraph \"$path\" {\n";
        print $fsmFile "    Reset [style=invis,shape=point,label=\"\",width=0,height=0];\n";
        for my $state (sort keys %states) {
            my $label = $states{$state};
            $label =~ s/_/\\l/g;
            print $fsmFile "    $state [label=\"$label\\l\"];\n";
        }
        print $fsmFile "    Reset -> $initialState;\n";
        for my $source (sort keys %states) {
            if ($source eq $glitchSource) {
                my $nSelfLoops = 0;
                for my $action (sort keys %actions) {
                    if ($action eq $glitchedAction) {
                        $nSelfLoops++ if ($glitchResult eq $source);
                    } else {
                        my $sink = $transitions{$source}->{$action};
                        $nSelfLoops++ if ($sink eq $source);
                    }
                }
                if ($nSelfLoops == scalar keys %actions) {
                    print $fsmFile "    $source -> $source [label=\"\"];\n";
                    next;
                } elsif ($nSelfLoops > 1) {
                    print $fsmFile "    $source -> $source [label=\"else\"];\n";
                }
                for my $action (sort keys %actions) {
                    if ($action eq $glitchedAction) {
                        next if ($glitchResult eq $source and $nSelfLoops > 1);
                        $action =~ s/_/\\l/g;
                        print $fsmFile "    $source -> $glitchResult [label=\"$action\\l\"];\n";
                    } else {
                        my $sink = $transitions{$source}->{$action};
                        next if ($sink eq $source and $nSelfLoops > 1);
                        $action =~ s/_/\\l/g;
                        print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
                    }
                }
            } else {
                my $nSelfLoops = 0;
                for my $action (sort keys %actions) {
                    my $sink = $transitions{$source}->{$action};
                    $nSelfLoops++ if ($sink eq $source);
                }
                if ($nSelfLoops == scalar keys %actions) {
                    print $fsmFile "    $source -> $source [label=\"\"];\n";
                    next;
                } elsif ($nSelfLoops > 1) {
                    print $fsmFile "    $source -> $source [label=\"else\"];\n";
                }
                for my $action (sort keys %actions) {
                    my $sink = $transitions{$source}->{$action};
                    $action =~ s/_/\\l/g;
                    next if ($sink eq $source and $nSelfLoops > 1);
                    print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
                }
            }
        }
        print $fsmFile "}\n";
    } elsif ($mtype eq "WO") {
        my ($wState, $gAction) = @_;
        my $extraState = $wState."_p";
        my $path = "${mutantPath}/mutant_${mIndex}_WO_${wState}_$fsmFilePath";
        open($fsmFile, ">", $path);
        print $fsmFile "digraph \"$path\" {\n";
        print $fsmFile "    Reset [style=invis,shape=point,label=\"\",width=0,height=0];\n";
        for my $state (sort keys %states) {
            my $label = $states{$state};
            $label =~ s/_/\\l/g;
            print $fsmFile "    $state [label=\"$label\\l\"];\n";
            print $fsmFile "    $extraState [label=\"$label\\l\"];\n" if ($state eq $wState);
        }
        print $fsmFile "    Reset -> $initialState;\n";
        for my $source (sort keys %states) {
            if ($source eq $wState) {
                my $nSelfLoops = 0;
                for my $action (sort keys %actions) {
                    next if ($action eq $gAction);
                    my $sink = $transitions{$source}->{$action};
                    $nSelfLoops++ if ($sink eq $source);                    
                }
                if ($nSelfLoops > 1) {
                    print $fsmFile "    $source -> $source [label=\"else\"];\n";
                }
                for my $action (sort keys %actions) {
                    if ($action eq $gAction) {                    
                        $action =~ s/_/\\l/g;
                        print $fsmFile "    $source -> $extraState [label=\"$action\\l\"];\n";
                    } else {
                        my $sink = $transitions{$source}->{$action};
                        next if ($sink eq $source and $nSelfLoops > 1);
                        $action =~ s/_/\\l/g;
                        print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
                    }
                }
            } else {
                my $nSelfLoops = 0;
                for my $action (sort keys %actions) {
                    my $sink = $transitions{$source}->{$action};
                    $nSelfLoops++ if ($sink eq $source);
                }
                if ($nSelfLoops == scalar keys %actions) {
                    print $fsmFile "    $source -> $source [label=\"\"];\n";
                    next;
                } elsif ($nSelfLoops > 1) {
                    print $fsmFile "    $source -> $source [label=\"else\"];\n";
                }
                for my $action (sort keys %actions) {
                    my $sink = $transitions{$source}->{$action};
                    next if ($sink eq $source and $nSelfLoops > 1);
                    $action =~ s/_/\\l/g;
                    print $fsmFile "    $source -> $sink [label=\"$action\\l\"];\n";
                }
            }
        }
        my $nSelfLoops = 0;
        for my $action (sort keys %actions) {
            my $sink = $transitions{$wState}->{$action};
            $nSelfLoops++ if ($sink eq $wState);
        }
        if ($nSelfLoops == scalar keys %actions) {
            print $fsmFile "    $extraState -> $extraState [label=\"\"];\n";
            next;
        } elsif ($nSelfLoops > 1) {
            print $fsmFile "    $extraState -> $extraState [label=\"else\"];\n";
        }
        for my $action (sort keys %actions) {        
            my $sink = $transitions{$wState}->{$action};
            next if ($sink eq $wState and $nSelfLoops > 1);
            $action =~ s/_/\\l/g;
            print $fsmFile "    $extraState -> $sink [label=\"$action\\l\"];\n";
        }
        print $fsmFile "}\n";
    } else { die "Unrecognized Mutation => $mtype"; }
    close($fsmFile);
}

mkdir "$mutantPath";
for my $state (sort keys %states) {
    next if ($state eq $initialState);
    $nMutants++;
    print "$nMutants : RG -> $state\n";
    mutateAndSave("RG", $state);
}
for my $state (sort keys %states) {
    $nMutants++;
    print "$nMutants : SF in $state\n";
    mutateAndSave("SF", $state);
}
for my $source (sort keys %states) {
    for my $action (sort keys %actions) {
        my $sink = $transitions{$source}->{$action};
        for my $tail (sort keys %states) {
            next if ($tail eq $sink);
            $nMutants++;
            print "$nMutants : TG $source->$action->$sink => $source->$action->$tail\n";
            mutateAndSave("TG", $source, $action, $tail);
        }
    }
}
for my $source (sort keys %states) {
    for my $action (sort keys %actions) {
        my $sink = $transitions{$source}->{$action};
        $nMutants++;
        print "$nMutants : WO $source->$action\n";
        mutateAndSave("WO", $source, $action);
    }
}

