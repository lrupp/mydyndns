#!/usr/bin/perl -w
#
# Copyright (C) 2014 by Lars Vogdt <lars@linux-schulserver.de>
# Author: Lars Vogdt
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the Novell nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

use strict;
use Carp;
use CGI;
use Config::Simple;
use DBI;
use POSIX qw(strftime);
use DNS::ZoneParse;
use Net::RNDC;

my $conf='/etc/mydyndns.conf'; 
my $debug=0;

# open config file
my $cfg=new Config::Simple($conf) or die "Could not open $conf : $!\n";
my $dbname=$cfg->param('dbname') || die "dbname not specified in $conf\n";
my $dbuser=$cfg->param('dbuser') || die "dbuser not specified in $conf\n";
my $dbpass=$cfg->param('dbpass') || die "dbpass not specified in $conf\n";
my $dbhost=$cfg->param('dbhost') || "localhost";

sub LOG($$$$;$$){
	my ($username,$action,$data,$dbh,$level,$loglevel)=@_;
        if ($level < $loglevel){
		my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
		my $sth = $dbh->prepare(qq{ INSERT INTO logs SET timestamp=?, username=?, action=?, data=? }) or carp "Can't prepare statement: $DBI::errstr\n";
		$sth->execute( $now, $username, $action, $data ) or carp "Can't execute statement: $DBI::errstr\n";
	}
	return;
}

sub GetConfigValue($$){
	my ($name,$dbh)=@_;
	my $sth=$dbh->prepare("SELECT value FROM config WHERE name=?") or carp "Can't prepare statement: $DBI::errstr\n";
	$sth->execute($name) or carp "Can't execute statement: $DBI::errstr\n";
	my ($value) = $sth->fetchrow_array();
	return $value;
}

sub CleanupAndExit($$){
	my ($exitcode,$dbh)=@_;
	if (defined($dbh)){
		$dbh->disconnect();
	}
	exit $exitcode;
}

sub DEBUG($){
	my ($output)=@_;
	if ($debug){
		print STDERR "$output\n";
	}
}

sub UpdateZoneFile($$$$){
	my ($zonefile_directory,$domain,$host,$ip)=@_;
	my $ttl=600;
	if (! -w "$zonefile_directory/$domain"){
		DEBUG("Could not find $zonefile_directory/$domain - exiting");
		CleanupAndExit(1,undef);
	}
	DEBUG("Will update $zonefile_directory/$domain");
	my $zonefile = DNS::ZoneParse->new("$zonefile_directory/$domain",$domain);
	my $a_records = $zonefile->a();
	my $num_records=@$a_records;
	if ($num_records > 0){
		my %seen =() ;
		my @unique_records = grep { ! $seen{$_}++ } @$a_records;
		undef $a_records;
		my @a_records=@unique_records;
		my $found=0;
		DEBUG("Current A Records: ");
		foreach my $record (@a_records){
			DEBUG("$record->{'name'} resolves at $record->{'host'}");
			if ("$record->{'name'}" eq "$host"){
				DEBUG("$host already exists - updating entry");
				$record->{'host'}=$ip;
				$found++;
				last;
			}
		}
		if (! $found){
				DEBUG("inserting new entry for $host");
				push (@a_records, { 	ORIGIN => "$domain.",
							name => $host, 
							class => 'IN',
							host => $ip,
							ttl => $ttl });
		}
	}
	else {
		DEBUG("Inserting first entry for $host");
		push (@$a_records, {    ORIGIN => "$domain.",
					name => $host,
                                        class => 'IN',
                                        host => $ip,
                                        ttl => $ttl });
	}
	$zonefile->new_serial();
	open(my $newzone, '>', "$zonefile_directory/$domain") or return "Error writing new Zone File $domain in $zonefile_directory : $!";
	print $newzone $zonefile->output();
	close $newzone;
	return("Successfully updated $zonefile_directory/$domain");
}

sub ReloadZoneFile($$$){
	my ($zonefile,$dbh,$loglevel) = @_;
	my $dns_host=GetConfigValue('dns_host',$dbh) || '127.0.0.1';
	my $dns_port=GetConfigValue('dns_port',$dbh) || 953;
	my $dns_key=GetConfigValue('dns_key',$dbh) || '';
	if ( "$dns_key" eq ''){
		DEBUG("Got no key for rndc calls - this might get wrong");
		LOG('root','Security','Got no key for rndc calls - please check you database entry for a valid dns_key',$dbh,1,$loglevel);
	}
	my $rndc = Net::RNDC->new(
				    	host => $dns_host,
					port => $dns_port,
					key  => $dns_key, );
	if (!$rndc->do('reload')){
		DEBUG("RNDC failed: " . $rndc->error);
		return("RNDC failed: " . $rndc->error);
	}
	else {
		DEBUG("Success: ".$rndc->response);
		return("Success: ".$rndc->response);
	}
}

sub PrintWeb($$){
	my ($q,$string)=@_;
	print $q->header;
	print $q->start_html($string);
	print "$string";
	print $q->end_html;
}

# parse external params
my $q = new CGI;
my $remote_user=$q->param('username');
$remote_user = '' unless (defined($remote_user) && ($remote_user =~ /^[0-9A-Za-z_\.\+-]*$/));
my $remote_pass=$q->param('password');
$remote_pass='' unless (defined($remote_pass) && ($remote_pass =~ /^[0-9A-Za-z_\.\+-]*$/));
my $remote_hostname=$q->param('hostname');
$remote_hostname='' unless (defined($remote_hostname) && ($remote_hostname =~ /^[0-9A-Za-z_\.\+-]*$/));
my $remote_ip=$q->param('myip');
$remote_ip='' unless (defined($remote_ip) && ($remote_ip =~ /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/));
if ("$remote_ip" eq ''){
    $remote_ip=$ENV{'REMOTE_ADDR'};
}

DEBUG("Got: $remote_user; $remote_pass; $remote_hostname; $remote_ip;");

# if we get no information at all, just print out the remote ip and exit
if ("$remote_pass" eq ""){
	PrintWeb($q,$remote_ip);
	CleanupAndExit(1,undef);
}

# start DB connection
my $dbh=DBI->connect(	"DBI:mysql:database=$dbname:host=$dbhost",
			"$dbuser", "$dbpass",
			{'RaiseError' => 1});

# get user information from database
my $loglevel=0;
$loglevel=GetConfigValue('loglevel',$dbh);
my $zonefile_directory='/var/lib/named/master';
$zonefile_directory=GetConfigValue('zonefile_directory',$dbh);
DEBUG("My loglevel=$loglevel");
DEBUG("My Zone files are in $zonefile_directory");

my $sql="SELECT username, password, user_id, active FROM users WHERE username=? LIMIT 1";
my @row = $dbh->selectrow_array($sql,undef,$remote_user);
unless (@row) { 
	DEBUG("user $remote_user not found in database"); 
	PrintWeb($q,'badauth');
	CleanupAndExit(1,$dbh);
}

my ($user, $pass, $user_id, $active) = @row;
if (! $active){
	DEBUG("User $remote_user exists but is marked as inactive");
	PrintWeb($q,'badauth');
	CleanupAndExit(1,$dbh);
} 
else {
	DEBUG("User $remote_user exists and is active - proceeding");
	if ("$remote_pass" ne "$pass"){
		DEBUG("Remote password '$remote_pass' does not match stored password '$pass' - exiting");
		PrintWeb($q,'badauth');
		CleanupAndExit(1,$dbh);
	}
	else {
		DEBUG("Passwords match - proceeding");
		$sql="SELECT host_id, host, domain, active, ip FROM hosts WHERE host=? LIMIT 1";
		@row = $dbh->selectrow_array($sql,undef,$remote_hostname);
		unless (@row) {
 			DEBUG("host $remote_hostname not found in database");
			LOG($user,'Security',"Host $remote_hostname not found in database",$dbh,2,$loglevel);
			PrintWeb($q,'nohost');
			CleanupAndExit(1,$dbh);
		}
		my ($host_id,$host,$domain,$active,$stored_ip) = @row;
		if (! $active){
			DEBUG("Host $remote_hostname exists but is marked as inactive");
			LOG($user,'Security',"Host $remote_hostname exists but is marked as inactive",$dbh,2,$loglevel);
			PrintWeb($q,'nohost');
			CleanupAndExit(1,$dbh);
		}
		if ("$remote_ip" eq "$stored_ip"){
			DEBUG("IP ($stored_ip) did not change for host $host - no need to do anything");
			LOG($user,'Notice',"IP ($stored_ip) did not change for host $host",$dbh,5,$loglevel);
			PrintWeb($q,'nochg');
			CleanupAndExit(1,$dbh);
		}
		$sql="SELECT * FROM `hosts_to_users` WHERE host_id=? AND user_id=?";
		@row = $dbh->selectrow_array($sql,undef,$host_id,$user_id);
		unless (@row) {
			DEBUG("User $user is not allowed to change $remote_hostname entry");
			LOG($user,'Security',"Tried to change $remote_hostname entry",$dbh,1,$loglevel);
			PrintWeb($q,'nohost');
			CleanupAndExit(1,$dbh);
		}
		DEBUG("Updating entry for host $remote_hostname now");
		if (defined($ENV{'REMOTE_ADDR'}) && ("$remote_ip" ne "$ENV{'REMOTE_ADDR'}")){
			DEBUG("Submitted remote IP $remote_ip does not match $ENV{'REMOTE_ADDR'} - will proceed nevertheless");
		}
		my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
		my $sth = $dbh->prepare(qq{ UPDATE hosts SET ip=?, modified=? WHERE host_id=? }) or die "Can't prepare statement: $DBI::errstr\n";
		$sth->execute( $remote_ip, $now, $host_id ) or die "Can't execute statement: $DBI::errstr\n";
		my $res=UpdateZoneFile($zonefile_directory,$domain,$host,$remote_ip);
		LOG($user,'UpdateZoneFile',$res,$dbh,3,$loglevel);
		$res=ReloadZoneFile($domain,$dbh,$loglevel);
		LOG($user,'ReloadZoneFile',$res,$dbh,4,$loglevel);
		LOG($user,'NewIP',"Updated $remote_ip for $host ($domain)",$dbh,1,$loglevel);
		PrintWeb($q,'good');
	}
}

# Disconnect from the database.
CleanupAndExit(0,$dbh);

