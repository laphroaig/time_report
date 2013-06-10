#!/usr/bin/perl
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# Ola Bodin wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.
# 
# Ola Bodin
#
# License based on Poul-Henning Kamp's <phk@FreeBSD.ORG> license
# ----------------------------------------------------------------------------
use strict;
use warnings;

# Constansts

my $TIME_HOUR = 3600;
my $TIME_WORK_DAY = 8 * $TIME_HOUR;

# Config data
my $DATA_DIR = '.';
my $LOG_FILE = 'time_log';

my %AN_CONF = {
    anSkippProject => {
        skippChar => '_',
    },
};

# Config keys
my $CK_LOG_PATH = "log_file";
my $CK_DATA_DIR = "data_dir";

# Local data
my @TIME_DATA;
my @TIME_DATA_hash;
my %CONFIG;
my @ANALYSIS_FUNCTOPNS = (
        \&anSkippProject,
        \&anLongEntry,
    );

sub initData {
    die "Data dir don't exists: $DATA_DIR\n" unless -d $DATA_DIR;
    my $logFilePath = $DATA_DIR . '/' . $LOG_FILE;
    die "Log file don't exists: $logFilePath\n" unless -e $logFilePath;
    $CONFIG{$CK_LOG_PATH} = $logFilePath;
}

sub readLog {
    my $logPath = $CONFIG{$CK_LOG_PATH};
    open FILE, $logPath or
        die "Failed to open file $logPath: $!";

    my $lastProject;
    my $lastTimestamp;
    my $time;

    while (<FILE>) {
        chomp;
        if (/.*#\s+(\d+)\s+#\s+(.*)/) {
            if ($lastProject) {
                $time = $1 - $lastTimestamp;
                push @TIME_DATA, [$lastProject, $1 - $lastTimestamp, $lastTimestamp];
                push @TIME_DATA_hash, {
                    project => $lastProject, 
                    timeDiff => $1 - $lastTimestamp, 
                    timeStamp => $lastTimestamp};
            }
            $lastProject = $2;
            $lastTimestamp = $1;
        }
    }

    close FILE;
}

sub ask {
    my $question = shift;
    my $input;
    my $q = $question;
    $q =~ s/[^\w]//g;
    $q = quotemeta $q;
    do {
        print "$question";
        $input = <STDIN>;
    } while (not $input =~ /(^[$q]$)|(^$)/i);

    if ($input =~ /([$q])/i) {
        return lc $1;
    } else {
        $question =~ /([A-Z])/;
        return lc $1;
    }
}

sub analyse_data {
    my $i;
    my %hash;

    foreach my $entry (@TIME_DATA_hash) {
        my $skipp = 'n';
        foreach my $anFunc (@ANALYSIS_FUNCTOPNS) {
            if (not $skipp =~ /y/i) {
                $skipp = &{$anFunc}($entry);
            }
            #$anFunc->();
        }

        if (not $skipp =~ /y/i) {
            $hash{$entry->{project}} += $entry->{timeDiff};
            #print "Adding $time to $project total is $hash{$project}\n";
        }
    }

#    foreach $i (0..@TIME_DATA-1) {
#        my $project = $TIME_DATA[$i][0];
#        my $time = $TIME_DATA[$i][1];
#        my $start_time = $TIME_DATA[$i][2];
#        
#        my $skipp;
#        if ($project =~ /^_/) {
#            #print "Skipping :" . $project . "\n";
#            $skipp = "y";
#        } elsif ($time > (8 * 3600)) {
#            my @timeArr = getHourAndMin($time);
#            print "Time entry for project $project is over 8h. " .
#                "($timeArr[0]h $timeArr[1]min)\n";
#            print "Skipp entry? ";
#            my $i = ask("(Y/n)");
#            if ($i =~ "y") {
#                $skipp = "y";
#            }
#        }

#        if (not $skipp) {
#            $hash{$project} += $time;
#            #print "Adding $time to $project total is $hash{$project}\n";
#        }
#    }

    %hash;
}

sub getHourAndMin {
    my $time = shift;

    my $hour = int($time / $TIME_HOUR);
    my $min = int(($time - ($hour * $TIME_HOUR)) / 60);

    ($hour, $min);
}

sub printDataHash {
    my $hash = shift;


    foreach (keys %{$hash}) {
        my @time = getHourAndMin($hash->{$_});
        printf "%20s => %3dh %2dmin\n", $_, $time[0], $time[1];
    }
}

sub debugPrintLog {
    my $row;
    my $column;
    for $row (0..@TIME_DATA-1) {
        for $column (0..@{$TIME_DATA[$row]}-1) {
            print $TIME_DATA[$row][$column] . ' ';
        }
        print "\n";
    }
    print "-----------\n";

    for my $entry (@TIME_DATA_hash) {
        print $entry->{project} . ' ';
        print $entry->{timeDiff} . ' ';
        print $entry->{timeStamp}. "\n";
    }
}

sub anLongEntry {
    my $entry = shift;

    my $q = 'n';
    if ($entry->{timeDiff} > $TIME_WORK_DAY) {
        my @timearr = getHourAndMin($entry->{timeDiff});
        print "time entry for project " .$entry->{project} . " is over 8h. " .
            "($timearr[0]h $timearr[1]min)\n";
        print "skipp entry? ";
        my $q = ask("(Y/n)");
    }

    return lc $q;
}

sub anSkippProject {
    my $entry = shift;

    my $skippChar = $AN_CONF{anSkippProject}->{skippChar};
    print "skippChar $skippChar\n". keys (&$AN_CONF{anSkippProject}) . "\n";
    if ($entry->{project} =~ /$skippChar/) {
        return 'y';
    } else {
        return 'n';
    }
}

initData();
readLog();
my %h = analyse_data();
#debugPrintLog();
printDataHash(\%h);
