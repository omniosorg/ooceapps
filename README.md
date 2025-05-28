<img src="https://www.omnios.org/OmniOSce_logo.svg" height="128">

ooceapps
========

[![Unit Tests](https://github.com/omniosorg/ooceapps/workflows/Unit%20Tests/badge.svg?branch=master&event=push)](https://github.com/omniosorg/ooceapps/actions?query=workflow%3A%22Unit+Tests%22)

Version: 0.10.20

Date: 2025-05-28

Web integrations for OmniOS Community Edition (OmniOSce) Association.

Setup
-----

To build `ooceapps` you require perl and gcc packages on your
system.

Get a copy of `ooceapps` from https://github.com/omniosorg/ooceapps/releases
and unpack it into your scratch directory and cd there.

    ./configure --prefix=$HOME/opt/ooceapps
    gmake

Configure will check if all requirements are met and give
hints on how to fix the situation if something is missing.

Any missing perl modules will be built and installed into the prefix
directory. Your system perl will NOT be affected by this.

To install the application, just run

    gmake install

Configuration
-------------

Take a look at the `ooceapps.conf.dist` file for inspiration.

---
This product includes GeoLite2 data created by MaxMind, available from
[http://www.maxmind.com](http://www.maxmind.com).

