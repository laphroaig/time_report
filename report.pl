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

use POSIX qw(isdigit);

# Config data
my $DATA_DIR = '.';
my $PROJECT_FILE = 'projects';
my $LOG_FILE = 'time_log';

my @END_OF_WORK = qw(_LUNCH hopp);
# Global variables
my $PROJECT_FILE_PATH = '';
my @PROJECTS = {};
my $PROJECT_INDEX = -1;
my $ARG_PROJ;
my $LOG_FILE_PATH;

my $TASK_REPORT = 1;
my $TASK_HELP = 2;
my $TASK_LIST = 3;
my $TASK_BREAK = 4;
my $TASK_CONTINUE = 5;

my $TASK;

sub printHelp {
    print 
<<EOI
SYNOPSIS
    Usage: $0 [-h] [-l] [-i index] [-p project_name]

    Adds a time stamp to the work log for the given project.

OPTIONS
    
    -i index
        Uses project with the given index. Projects are indexed from
        0 statting at the first line in the projects file.

    -p project_name
        Uses project with the gien name.

    -h print this help message.

    -l pint list of all projects.

    -b end current project and stat a break in the log.

    -c continue last project in the log.
EOI
}

sub checkForTask {
    if ($TASK) {
        printHelp();
        die;
    }
}

sub readArgs {
    my $op = shift @ARGV;

    while ($op) {
        
        if ($op eq '-i') {
            checkForTask();
            my $i  = shift @ARGV;
            if (isdigit($i)) {
                $PROJECT_INDEX = $i;
            } else {
                printHelp();
                die "$i is not a valid index";
            }
            $TASK = $TASK_REPORT;
        } elsif ($op eq '-p') {
            checkForTask();
            $ARG_PROJ = shift @ARGV;
            unless ($ARG_PROJ) {
                printHelp();
                die "Missing argument";
            }
            $TASK = $TASK_REPORT;
        } elsif ($op eq '-l') {
            checkForTask();
            $TASK = $TASK_LIST;
        } elsif ($op eq '-b') {
            checkForTask();
            $TASK = $TASK_BREAK;
        } elsif ($op eq '-c') {
            checkForTask();
            $TASK = $TASK_CONTINUE;
        } else {
            printHelp();
            die "Unknown argument $op";
        }

        $op = shift @ARGV;
    }
}

sub initData {
    $PROJECT_FILE_PATH = $DATA_DIR . '/' . $PROJECT_FILE;
    $LOG_FILE_PATH = $DATA_DIR . '/' . $LOG_FILE;

    @PROJECTS = read_projectes();
}

sub read_projectes {
    open FILE, $PROJECT_FILE or 
        die "Failed to open file $PROJECT_FILE: " . $!;

    my @ar;
    while (<FILE>) {
        chomp;
        push @ar, $_;
    }

    close FILE;

    @ar;
}

sub read_project_id {
    if ($PROJECT_INDEX == -1) {
        unless ($ARG_PROJ) {
            chomp ($ARG_PROJ = <STDIN>);
        }

        my $i = 0;
        while ($i < @PROJECTS) {
            if ($ARG_PROJ eq $PROJECTS[$i]) {
                $PROJECT_INDEX = $i;
                $i = @PROJECTS;
            }
            $i++;
        }
        if ($PROJECT_INDEX == -1) {
            printHelp();
            die "Found no project with name $ARG_PROJ";
        }
    } elsif ($PROJECT_INDEX >= @PROJECTS) {
        printHelp();
        die "No such index $PROJECT_INDEX";
    }
}

sub print_to_log {
    my $project = $_[0];
    my $time = $_[1];

    my @date = localtime $time;
    my $logLine = sprintf ("%s # %d # %s\n", scalar localtime($time), $time, $project);

    open FILE, ">>", $LOG_FILE_PATH or 
        die "Failed to open file $LOG_FILE_PATH: $!";

    print "$logLine";
    print FILE "$logLine";
    close FILE;
}

sub printProjects {
    my @projects = @_;

    print "Projectes:\n";
    print "Index   Name\n";
    my $i = 0;
    my $project;
    foreach (@_) {
        if (/_([A-Z_]+)/) {
            $project = $1;
            $project =~ s/_/ /g;
            $project = lc $project;
        } else {
            $project = $_;
        }
        printf "%3d:    %s\n", $i, $project;
        $i++;
    }
}

sub getLastProject() {
    open FILE, $LOG_FILE_PATH or
        die "Failed to open file $LOG_FILE_PATH: $!";

    my $last;
    while (<FILE>) {
        chomp;
        if (/.*#.*#\s+(.*)/) {
            if ($1 =~ /^_/) {
            } else {
                $last = $1;
            }
        }
    }

    close FILE;
    $last;
}

sub doTask() {
    if (not $TASK) {
        printHelp();
        die;
    }

    if ($TASK == $TASK_REPORT) {
        read_project_id();
        print_to_log($PROJECTS[$PROJECT_INDEX], time);
    } elsif ($TASK == $TASK_LIST) {
        printProjects(@PROJECTS);
    } elsif ($TASK == $TASK_BREAK) {
        print_to_log("_BREAK", time);
    } elsif ($TASK == $TASK_CONTINUE) {
        my $last = getLastProject();
        if ($last) {
            print_to_log($last, time);
        } else {
            die "No last project to continue";
        }
    }
}

readArgs();
initData();
doTask();
