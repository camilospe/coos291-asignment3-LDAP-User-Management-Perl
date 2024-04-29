#!/usr/bin/perl -w

use strict;
use IO::Socket;
use lib '/usr/share/migrationtools';
use Cwd;

my $dir = getcwd;

my $currentGroup;

my $baseDn;

my $groupId;

my $currentGid;

sub setGroup {

    $currentGroup = shift @_;
    chomp($currentGroup);

    $currentGid = shift @_;
}

# Function to find an available GID in the range from 6000 to 5000
sub findAvailableGid {
    # Hash to store both UIDs and GIDs
    my %used_ids;

    # Open the /etc/passwd file
    open my $passwd, '<', '/etc/passwd' or die "Could not open /etc/passwd: $!";

    # Read each line from the passwd file
    while (my $line = <$passwd>) {
        chomp $line;
        my @fields = split(':', $line);

        # UIDs are in the third field, GIDs in the fourth
        $used_ids{$fields[2]} = 1;
        $used_ids{$fields[3]} = 1;
    }

    # Close the file
    close $passwd;

  # Open the /etc/group file
    open my $group, '<', '/etc/group' or die "Could not open /etc/group: $!";
    # Read each line from the group file
    while (my $line = <$group>) {
        chomp $line;
        my @fields = split(':', $line);
        # GIDs are in the third field of the group file
        $used_ids{$fields[2]} = 1;
    }
    close $group;



    # Iterate from 6000 down to 5000 to find an unused ID
    for (my $id = 6000; $id >= 5000; $id--) {
        unless (exists $used_ids{$id}) {
            return $id;  # Return the first available ID
        }
    }

    return undef;  # Return undefined if no ID is found
}

# Function to find an available UID in the range from  5000 to 6000
sub findAvailableUid {
    # Hash to store both UIDs and GIDs
    my %used_ids;

    # Open the /etc/passwd file
    open my $passwd, '<', '/etc/passwd' or die "Could not open /etc/passwd: $!";
    # Read each line from the passwd file
    while (my $line = <$passwd>) {
        chomp $line;
        my @fields = split(':', $line);
        # UIDs are in the third field, GIDs in the fourth
        $used_ids{$fields[2]} = 1;
        $used_ids{$fields[3]} = 1;
    }
    close $passwd;

    # Open the /etc/group file
    open my $group, '<', '/etc/group' or die "Could not open /etc/group: $!";
    # Read each line from the group file
    while (my $line = <$group>) {
        chomp $line;
        my @fields = split(':', $line);
        # GIDs are in the third field of the group file
        $used_ids{$fields[2]} = 1;
    }
    close $group;

    # Iterate from 5000 to 6000
    for (my $id = 5000; $id <= 6000; $id++) {
        unless (exists $used_ids{$id}) {
            return $id;  # Return the first available ID
        }
    }

    return undef;  # Return undefined if no ID is found
}



sub createGroup
{
	my $groupName = shift @_; 	
	my $groupID =  shift @_;

	`sudo groupadd -g $groupID $groupName`;


	`sudo mkdir /home/$groupName`;

	`sudo chown :$groupName /home/$groupName`;

	setGroup($groupName, $groupID);
	
	# Change directory using Perl's built-in function
    	chdir('/usr/share/migrationtools') or die "Cannot change directory: $!";

	`sudo ./migrate_group.pl /etc/group > $dir/newGroup.ldif`;
	
	chdir($dir) or die "Cannot change directory: $!";

	# Open LDIF file and extract from the last 'dn: cn='
        open(my $fh, '<', "$dir/newGroup.ldif") or die "Cannot open file: $!";
        my @lines = <$fh>;  # Read all lines into an array
        close $fh;

        # Reverse array to find the last occurrence from the end towards the start
        my $index = -1;
        for (my $i = $#lines; $i >= 0; $i--) {
            if ($lines[$i] =~ /^dn: cn=/) {
                $index = $i;
                last;
            }
        }

        # Open the file again to write the desired contents
        open(my $fh_write, '>', "$dir/newGroup.ldif") or die "Cannot open file: $!";
        print $fh_write @lines[$index..$#lines];  # Print from the last 'dn: cn=' to the end
        close $fh_write;

        print "Updated LDIF file is ready.\n";
	
	print "$baseDn";
	`sudo ldapadd -x -D "$baseDn" -w nuts -f newGroup.ldif`;

}



sub searchGroup {
    # Get the group name passed as an argument and remove any trailing newlines
    my $groupName = shift @_;
    chomp($groupName);

    # Execute LDAP search with dynamic group name and store the output in a file
    `sudo ldapsearch -x -b "$baseDn" '(&(objectClass=posixGroup)(cn=$groupName))' > groupSearch.txt`;

    # Extract the gidNumber using grep and awk
    my $groupId = `grep gidNumber: groupSearch.txt | awk '{print \$2}'`;
    chomp($groupId); # Remove any trailing newline

    # Check if groupId is empty
    if ($groupId) 
    {
	setGroup($groupName, $groupId);
        return "found";
    } else 
    {
	createGroup($groupName,findAvailableGid());
	return "new";
    }
}


sub userlist {
        print "getting list of LDAP users \n"; 

	#grab the ldap config options

	my $userList = `sudo slapcat | head -n 1 `;
        ($userList) = $userList =~ /(dc=.*)/;
        print "$userList\n";


	`sudo slapcat > slapcat.txt`;

	 # Read the file content and grep for user ids
        my $users = `grep uid: slapcat.txt`;

        # Remove 'uid: ' part and trailing whitespaces/newlines
        $users =~ s/uid: //g;
        $users =~ s/\n/,/g;
        $users =~ s/,$//; # Remove the last comma

	print "$users\n";

	return $users ;
}

sub grouplist {
	# Use ldapsearch to find posixGroup entries
	my $results = `sudo ldapsearch -x -b "$baseDn" '(objectClass=posixGroup)' cn`;
	my @groups;
	# Extract group names from the results
	foreach my $line (split /\n/, $results) 
	{
        	if ($line =~ /^\s*cn:\s*(.+)$/i) 
		{
            		push @groups, $1;
		}
	}

    # Join group names with commas and print
    my $groupStr = join ', ', @groups;
    print "$groupStr\n";

    return $groupStr ;
}

sub server {
	#grab the base configuration from slapcat
	$baseDn = `sudo slapcat | head -n 1 `;
	($baseDn) = $baseDn =~ /(dc=.*)/;


    print "starting server\n";
    my $ipAddress = `hostname -I`;

    #createGroup("Roma",findAvailableGid());
  
    my @ips = split(' ', $ipAddress);
    $ipAddress = $ips[0]; 
    chomp($ipAddress);

    print "The current ip address is $ipAddress\n";


     my $socket = new IO::Socket::INET(
        LocalHost => $ipAddress,
        LocalPort => 10912,
        Proto => 'tcp',
        Listen => 10,  # Increase if needed
        Reuse => 1
    ) or die "Could not create the socket: $!\n";

    print "Waiting for data from the client\n";

     while (1) {
        my $new_socket = $socket->accept();
        if (fork() == 0) {
            $| = 1;  # Enable autoflush for the child process

            my $waiting_for_group_name = 0;

            while (my $line = <$new_socket>) {
		print "$line\n";    
                chomp $line;
                if ($waiting_for_group_name) {

			my $searchResult = searchGroup($line);

			if($searchResult eq "found")
			{
				print $new_socket "Set\n";
			}

			else
			{
				print $new_socket "Created\n";
			}
                    $waiting_for_group_name = 0;
                    next;
                }

                if ($line eq "setgroup") {
                    $waiting_for_group_name = 1;
                    print $new_socket "Please send the group name:\n";
                }

		elsif ($line eq "userlist")
		{
			my $userlist =  userlist();

			print $new_socket "$userlist\n";		
		}
		elsif ($line eq "grouplist")
		{
			my $grouplist = grouplist();
			print $new_socket "$grouplist\n";
		}
            }
            close $new_socket;
            exit(0);
        }
        close $new_socket;  # Parent closes socket used by child
    }
}

sub client {
    my $ipAddress = shift;
    print "Starting client with connection to $ipAddress\n";

    my $socket = new IO::Socket::INET(
        PeerAddr => $ipAddress,
        PeerPort => 10912,
        Proto    => 'tcp',
    ) or die "Could not create socket: $!\n";

    if (fork() == 0) {
        while (my $response = <$socket>) {
            print $response;
        }
        exit(0);
    }

    print "Please enter a command:\n";
    while (my $clientCommand = <STDIN>) {
        chomp $clientCommand;
        if ($clientCommand eq "exit") {
            print $socket "$clientCommand\n";
            last;
        }
        print $socket "$clientCommand\n";
    }

    close $socket;
    wait();  # Wait for the child process to finish
    print "Connection closed.\n";
}

my $ipAddress = $ARGV[0];
if (defined($ipAddress)) {
    client($ipAddress);
} else {
    server();
}
