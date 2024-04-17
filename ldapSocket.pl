#!/usr/bin/perl -w

use strict;
use IO::Socket;

sub server
{
	print "starting server\n";


	my $ipAddress = `hostname -I`;
    	print "Raw IP addresses: $ipAddress";  # Debugging line to see the raw output
    	
	my @ips = split(' ', $ipAddress);  # Split the string into an array by spaces
    	
	$ipAddress = $ips[0];  # Select the first IP address
    	
	chomp($ipAddress);

	print "The current ip adress is $ipAddress\n";

	
	my $socket = new IO::Socket::INET(

        LocalHost => $ipAddress,
        LocalPort => 10912,
        Proto => 'tcp',
        Listen => 1,
        Reuse => 1
	);


	die "Could not create the socket: $!\n" unless $socket;


	print "Waiting data from the client \n";

	while(1)
	{
        	my $new_socket = $socket->accept();

        	if (fork==0)
        	{

               		while(<$new_socket>)
                	{
                        	print $_ ;
                	}

                	last;
        	}

	}
}

sub client 
{
	
	my $ipAddress = shift @_;
	
	print "starting client with connection to $ipAddress\n";

	my $socket = new IO::Socket::INET(

        	PeerAddr => $ipAddress,
        	PeerPort => 10912,
        	Proto => 'tcp'
        );
	

        die "Could not create the socket " unless $socket;

        print "Please enter a command \n";


	while(my $clientCommand = <>)
	{
		print $socket "From client" . $clientCommand;
		print "$clientCommand\n";
	}
}


my $ipAddress = $ARGV[0];

if(defined($ipAddress))
{
	client($ipAddress);
}
else
{

	server();
}

