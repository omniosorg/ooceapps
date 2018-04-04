<img src="http://www.omniosce.org/OmniOSce_logo.svg" height="128">

ooceapps
========

[![Build Status](https://travis-ci.org/omniosorg/ooceapps.svg?branch=master)](https://travis-ci.org/omniosorg/ooceapps)

Version: 0.3.4

Date: 2018-04-04

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
This product includes GeoLite data created by MaxMind, available from
[http://www.maxmind.com](http://www.maxmind.com).

