mydyndns
========

My own DynDNS service.

The idea behind this little script is to provide something similar to dnynds.org and other hosters:
A service that can be run on your own server in the internet and used by as many clients under as 
many subdomains you like to host.

Requirements
------------

* A database. Tested with MySQL but PostgreSQL and other perl(DBI) supported database should also work
  with some small adaptions
* mod_perl or similar enabled on your Webserver (Tested with mod_perl on Apache2)
* The following Perl modules installed on the system:
 * Carp
 * CGI
 * Config::Simple
 * DBI
 * DNS::ZoneParse
 * Net::RNDC
 * POSIX

Configuration
-------------

Please add the database connection information to the etc/mydyndns.conf file and place it in 
your configuration directory (/etc/mydyndns.conf).

The rest of the configuration is done in the database itself.

###Bind configuration

As the script is executed with the rights of the webserver, I recommend to create a subdomain file
for your dyndns hosts. The script asumes that the files are named like the domain, so in the example 
this means it expects a file named 'dyn.example.com' in '/var/lib/named/dyndns'. 

This should be included in the named.conf like:

    zone "dyn.example.com" {
        type master;
        file "dyndns/dyn.example.com";
    };


Database setup
--------------

For MySQL there is a dump in the sql/ subdirectory. Please check and adapt to your configuration.

Examples
--------

The following options are mandatory:
* username
* password
* hostname

The following options are optional if you run in the webserver context:
* myip

If 'myip' is not given, the script relies on the 'REMOTE_ADDR' value provided by the webserver. If this one does also not exist, it will use 127.0.0.1.

###Using the commandline 

Might be used for testing purposes on the server:

    ./dyndns.pl username=username password=password hostname=hostname  myip=127.0.0.1
    
Please note that the script has a "$debug" variable that can be set to '1' to get some output on STDERR. Please note that this debug output will end up in your apache logfiles if you do not turn it off again.

####Using wget

This might be the simplest way to get your DNS updated from the client:

    wget https://<yourdomain>/cgi-bin/dyndns.pl?username=username&password=password&hostname=hostname&myip=127.0.0.1
    
Running this via a cron job should not not be that big problem. Please have a look into the client/ folder to get an idea for your own scripts.



