Trappola Trap Receiver
======================

This is the receiving part of Trappola.

Prerequisites
-------------

To run this software you need:

* a Redis installation
* a MySQL (or compatible) database server
* Perl
* Perl-libraries: Sys::Syslog, JSON, Try::Tiny, DBI::MySQL

It is perfectly legal to have Redis and/or MySQL on another server. Please think
about security and encryption in that case. You might want to install the Perl
Redis library. As most distribtions to not provide it as a package, for convenience
it is currently shipped with this repository. When working with Oracle Linux please
do not forget to enable the `ol7_optional` yum repository first.

Installation
------------

For installation please clone or extract this repository on your trap-receiving
system, preferably to `/usr/local/trappola` or similar. Then please install
snmptrapd from the Net-SNMP package and add the following to your
`/etc/snmp/snmptrapd.conf`:

    outputOption Ubentaq
    perl do "/usr/local/trappola/bin/trappola-receiver"

You might also want to configure some authentication:

    authCommunity execute,net public

You should of course opt for a better community string (or even better, SNMPv3),
but configuring those options is out of the scope of this document. Depending on
your OS you might see every single trap in your syslog. In case you do not like
his disabling logging might help:

    doNotLogTraps yes

There could also be some options overriding specific logging-related settings in
other places. Your operating system might use command line parameters with an
influence on those flags, so please check `/etc/sysconfig` or `/etc/default` for
such settings. Setting CONFIG="" often helps, but please read the documentation
referring the used options first.

What are those flags all about?
-------------------------------

We need snmptrapd to provide plain OIDs and to not do any lookup and/or
transformation at all. The flags used the in outputOption shown above are the
following:

* U = Do not print the UNITS suffix at the end of the value
* b = Display table indexes numerically
* e = Removes the symbolic labels from enumeration value
* n = Displays the OID numerically
* t = Display TimeTicks values as raw numbers
* a = Display  string  values  as  ASCII strings unless there is a DISPLAY-HINT
* q = Removes the equal sign and type information when displaying varbind values:

Trappola configuration
----------------------

Trappola expects it's configuration in `/etc/trappola/config.ini`. It might look
as follows:

```ini
[redis]
host = localhost
; port = 6379
```

Redis defaults to localhost:6379, it's config section is not required in case
this fits your environment.

OID cache resolver
------------------

Another involved component is the OID cache resolver. It needs to be running
on demand or constantly. The database is not required by the Trap receiver itself
but by the OID cache resolver. You can add it to your `config.ini`:

`snmptrapd service`.


```ini
[db]
host = localhost
dbname = trappola
username = trappola
password = "x x x"
```

A Systemd unit file like the following is the preferred way to keep it alive
(`/etc/systemd/system/trappola-oid-cache.service`):

```ini
[Install]
WantedBy=multi-user.target

[Unit]
Description=Trappola OID Cache MIB Resolver

[Service]
Type=simple
ExecStart=/usr/local/trappola/bin/trappola-refresh-oidcache
Restart=on-success
```

Then please refresh systemd, enable and start the service:

```
systemctl daemon-reload
systemctl enable trappola-oid-cache.service
systemctl start trappola-oid-cache.service
```

And now?
--------

Please also read about the related web/cli component, it has it's own [repository](https://github.com/Thomas-Gelf/icingaweb2-module-trappola)
and [documentation](https://github.com/Thomas-Gelf/icingaweb2-module-trappola/blob/master/README.md)
