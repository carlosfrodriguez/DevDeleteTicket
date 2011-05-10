#!/usr/bin/perl -w
# --
# bin/otrs.DevDeleteTicket.pl - Delete Tikets
# This package is intended to work on Development and Testing Environments
# Copyright (C) 2011 Carlos Rodriguez, http://otrs.org/
# --
# $Id: otrs.DevDeleteTicket.pl,v 1.0 2011/04/30 00:00:00 cr Exp $
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# or see http://www.gnu.org/licenses/agpl.txt.
#
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . "/Kernel/cpan-lib";

use vars qw($VERSION);
$VERSION = qw($Revision: 0.1 $) [1];

use Getopt::Std;
use Kernel::Config;
use Kernel::System::Encode;
use Kernel::System::Log;
use Kernel::System::DB;
use Kernel::System::Main;
use Kernel::System::Ticket;


    my %CommonObject;
    $CommonObject{ConfigObject} = Kernel::Config->new();
    $CommonObject{EncodeObject} = Kernel::System::Encode->new(%CommonObject);
    $CommonObject{LogObject}    = Kernel::System::Log->new(
        LogPrefix => 'otrs.DevDeleteTicket',
        %CommonObject,
    );
    $CommonObject{MainObject}   = Kernel::System::Main->new(%CommonObject);
    $CommonObject{TimeObject}   = Kernel::System::Time->new(%CommonObject);
    $CommonObject{DBObject}     = Kernel::System::DB->new(%CommonObject);
    $CommonObject{TicketObject} = Kernel::System::Ticket->new(%CommonObject);


# get options
my %Opts = ();
getopt( 'haixn', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'list' ){
    _List();
}
elsif ( $Opts{a} && $Opts{a} eq 'delete' ) {

    my $ExitCode;

    # check if ticket id is passed
    if ( $Opts{i} ){

            # check if ID is numeric valid
            if ($Opts{i} !~ m{\d+} ) {
                print "The Ticket ID $Opts{i} is invalid!\n";
                _Help();
                exit 0;
            }
            else {

                # delete ticket by ID
                _Delete( TicketID => $Opts{i} );
            }
    }

    # check if delete all tickets
    elsif ( $Opts{x} ) {
        if ( $Opts{x} eq 1 ) {

            # delete all tickets except form otrs welcome ticket
            $ExitCode = _Delete(
                All           => 1,
                ExceptWelcome => 1,
            );
            if ($ExitCode){
                exit 1;
            }
            exit 0;
        }
        else {

            # delete all tickets
            $ExitCode = _Delete ( All => 1 );
            if ($ExitCode){
                exit 1;
            }
            exit 0;
        }
    }
    else {
        print "Invalid option!\n";
        _Help();
        exit 0;
    }
}
elsif ( $Opts{a} && $Opts{a} eq 'search' ) {

    my %SearchOptions;

    if ( $Opts{n} ) {
        $SearchOptions{TicketNumber} = $Opts{n};
    }

    _search( SearchOptions => \%SearchOptions );

}
else {
    _Help();
    exit 1;
}

# Internal

sub _List {

    # search all tickets
    my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
        Result  => 'ARRAY',
        UserID  => 1,
        SortBy  => 'Age',
        OrderBy => 'Up',
    );

    _Output( TicketIDs => \@TicketIDs );
}

sub _search {
    my %Param = @_;

    my %SearchOptions = %{ $Param{SearchOptions} };


    # search all tickets
    my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
        Result  => 'ARRAY',
        UserID  => 1,
        SortBy  => 'Age',
        OrderBy => 'Up',
        %SearchOptions,
    );

    _Output( TicketIDs => \@TicketIDs );
}


sub _Output{
    my %Param = @_;

    my @TicketIDs = @{ $Param{TicketIDs} };

    # to store all ticket details
    my @Tickets;

    for my $TicketID ( @TicketIDs ) {

        next if !$TicketID;

        # get ticket details
        my %Ticket = $CommonObject{TicketObject}->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        next if !%Ticket;

        # store ticket details
       push @Tickets, \%Ticket,
    }

    my %ColumnLength = (
        ID       => 7,
        Number   => 20,
        Owner    => 24,
        Customer => 24,
        Title    => 24,
    );

    # print header
    print "\n";
    for my $HeaderName ( qw(ID Number Owner Customer Title) ) {
        my $HeaderLength = length $HeaderName;
        my $WhiteSpaces;
        if ( $HeaderLength < $ColumnLength{$HeaderName} ) {
            $WhiteSpaces = $ColumnLength{$HeaderName} - $HeaderLength;
        }
        print $HeaderName;
        if ($WhiteSpaces) {
            for ( 0 .. $WhiteSpaces ) {
                print " ";
            }
        }
    }
    print "\n";

    for ( 1..100 ) {
        print '=';
    }
    print "\n";

    # print each ticket row
    for my $Ticket (@Tickets) {

        # prepare ticket information
        $Ticket->{ID}       = $Ticket->{TicketID} || '';
        $Ticket->{Number}   = $Ticket->{TicketNumber} || '';
        $Ticket->{Owner}    = $Ticket->{Owner} || '';
        $Ticket->{Customer} = $Ticket->{CustomerUserID} || '';
        $Ticket->{Title}    = $Ticket->{Title} || '';

        # print ticket row
        for my $Element ( qw(ID Number Owner Customer Title) ) {
            my $ElementLength = length $Ticket->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $ColumnLength{$Element} ) {
                $WhiteSpaces = $ColumnLength{$Element} - $ElementLength;
            }
            print $Ticket->{$Element};
            if ($WhiteSpaces) {
                for ( 0 .. $WhiteSpaces ) {
                    print " ";
                }
            }
        }
        print "\n";
    }
    print "\n";

}

sub _Delete{
    my %Param = @_;

    # check needed parameters
    if ( !$Param{TicketID} && !$Param{All} ){
        print "Need \"TicketID\" or \"All\" parameter\n";
        _Help();
        exit 1;
    }

    # check if both parameters are passed
    if ( !$Param{TicketID} && !$Param{All} ){
        print "Can't use both \"TicketID\" and \"All\" parameters at the same time";
        _Help();
        exit 1;
    }

    # to store the tickets to be deleted
    my @TicketIDsToDelete;

    # delete one ticket
    if ( $Param{TicketID} ){
        push @TicketIDsToDelete, $Param{TicketID};
    }

    # delete all tickets
    if ( $Param{All} ){

        # search all tickets
        my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
            Result  => 'ARRAY',
            UserID  => 1,
            SortBy  => 'Age',
            OrderBy => 'Up',
        );
        @TicketIDsToDelete = @TicketIDs;
    }

    # to store exit value
    my $Failed;

    TICKETID:
    for my $TicketID ( @TicketIDsToDelete ) {

        next TICKETID if !$TicketID;

        next TICKETID if $TicketID eq 1 && $Param{ExceptWelcome};

        # get ticket details
        my %Ticket = $CommonObject{TicketObject}->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # check if ticket exists
        if ( !%Ticket ){
            print "The ticket with ID $Param{TicketID} does not exist!\n";
            $Failed = 1;
            next TICKETID;
        }

        # delete ticket
        my $Success = $CommonObject{TicketObject}->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        if (!$Success) {
            print "Can't delete ticket $TicketID\n";
            $Failed = 1;
        }
    }
    return $Failed;
};

sub _Help {
    print <<"EOF";
otrs.DevDeleteTicket.pl <Revision $VERSION> - Command line interface to delete tickets.

Usage: otrs.DevDeleteTicket.pl
Options:
    -a list                     # list all tickets
    -a search -n *1234*     # search tickets with specified ticket number (wild cards are allowed)
    -a delete -i 123        # deletes the ticket with ID 123
    -a delete -x 1           # deletes all tickets in the system except otrs welcome ticket
    -a delete -x 2           # deletes all tickets in the system including otrs welcome ticket
Copyright (C) 2011 Carlos Rodriguez

EOF

#TODO Implement
#    -a search -f => Text,       # Full text search
#    -a search -c => carlos,     # Ticket customer login
#    -a search -i => 123,        # Ticket ID
#    -a serach -o => cr@wolf.net # Ticket owner login

}
