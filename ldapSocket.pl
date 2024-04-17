#!/usr/bin/perl -w

use strict;
use IO::Socket;


sub server
{
	print "starting server\n";
	my $socket = new IO::Socket::INET(

        LocalHost => "172.16.1.76",
        LocalPort => 10912,
        Proto => 'tcp',
        Listen => 1,
        Reuse => 1
	);


	die "Could not create the socket " unless $socket;

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
	print "starting client\n";
	my $socket = new IO::Socket::INET(

        	LocalHost => "172.16.1.76",
        	LocalPort => 10912,
        	Proto => 'tcp',
        	Listen => 1,
        	Reuse => 1
        );


        die "Could not create the socket " unless $socket;

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


my $ipAddress = $ARGV[0];

if(defined($ipAddress))
{
	client($ipAddress);
}
else
{

	server();
}

