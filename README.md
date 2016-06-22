Trappola Trap Reciever
======================

This is the receiving part of Trappola. 

Prerequisites
-------------

To run this software you need:

* a Redis installation
* a MySQL (or compatible) database server
* Perl
* DBI::MySQL

You might want to install the Perl Redis library. As most distribtions to not
provide it as a package, for convenience it is currently shipped with this
repository.

Installation
------------

For installation please clone or extract this repository on your trap-receiving
system, preferably to `/usr/local/trappola` or similar. Then please install
snmptrapd from the Net-SNMP package and add the following to your
`/etc/snmp/snmptrapd.conf`:

    outputOption Ubentaq
    perl do "/usr/local/trappola/bin/trappola-receiver"

Your operating system might use command line parameters with an influence
on those flags, so please eventually also check for such settings in
`/etc/sysconfig` or `/etc/default`.

Trappola configuration
----------------------

Trappola expects it's configuration in `/etc/trappola/config.ini`. It might look
as follows:

[redis]
host = localhost
; port = 6379

[db]
host = localhost
dbname = trappola
username = trappola
password = "x x x"

Redis defaults to localhost:6379, it's config section is not required in case
this fits your environment. The database is not required by the Trap receiver
but by the OID cache resolver. You are now ready to restart your `snmptrapd`
service.

Another involved component is the OID cache resolver. It needs to be running
on demand or constantly. A Systemd unit file like the following is the preferred
way to keep it alive:

```ini
[Unit]
Description=Trappola OID Cache MIB Resolver

[Service]
Type=simple
ExecStart=/usr/local/trappola/bin/trappola-refresh-oidcache
Restart=on-success
```

What are those flags all about?
-------------------------------

We need snmptrapd to provide plain OIDs and to not do any lookup and/or
transformation at all. The flags used in outputOption are the following:

* U = Do not print the UNITS suffix at the end of the value
* b = Display table indexes numerically
* e = Removes the symbolic labels from enumeration value
* n = Displays the OID numerically
* t = Display TimeTicks values as raw numbers
* a = Display  string  values  as  ASCII strings unless there is a DISPLAY-HINT
* q = Removes the equal sign and type information when displaying varbind values:

