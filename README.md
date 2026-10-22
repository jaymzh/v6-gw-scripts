# v6-gw-scripts

These are scripts to helpe people setup a v6 gateway on ISPs who support requestiong IPv6 blocks via DHCPv6.

These scripts have been tested on both Comcast/Xfinity and GFiber/Webpass.

I've only tested these on Debian, but they should work on Fedora-derived distributions as well.

## Prerequisites

You will need a DHCP client that can run scripts on leases. Both the ISC DHCP client (`isc-dhcp-client` on Debian/Ubuntu) and `dhcpcd` on Fedora/RHEL/CentOS should work, though I've only tested these with ISC's client.

You will also need some Router Advertisement daemon - we support `radvd` or `dnsmasq` (though I recommend `radvd`).

## Setup

### Configuration

Start by creating a config file. All scripts in this repo read
`/etc/ipv6_prefix_dhclient.conf`, a file in shell format. See the sample
`ipv6_prefix_dhclient.conf` in this directory for a list of all supported
variables and a description of what they do.

### IPv6 hook for your network stack

The first step is to install the `99-ipv6` hook script into the relevant place for your network manager. This script is what fires off the DHCPv6 request when your interfaces comes up. It handles requesting the right number and size of block based on your needs (see [Configuration](#Configuration) below).

Copy it to the right location:

* For `ifup`, that's `/etc/network/if-up.d/`
* For `NetworkManager`, that's `/etc/NetworkManager/dispatcher.d/` (though these scripts have not been tested with NM)
* For `systemd-networkd`, you'll have to use something like `netword-dispatcher`

Note that you should *not* add a `inet6` entry for your interface in
`/etc/network/interfaces`. These scripts use the v4 up event to kick off the v6
configuration.

### Configuration hook for your DHCP client

Once you have your addresses, this hook will update the addresses on the relevant interface(s) and update your `radvd` or `dnsmasq` configuration with the relevant addresses.

Copy `dhclient-ipv6` to the relevant location for your DHCP client:

* On Debian (ISC) this is `/etc/dhcp/dhclient-exit-hooks.d``
* On Fedora-like (DHCPCD) this is `/etc/dhcpcd.exit-hook/`

### RA Daemon

These scripts can now support `dnsmasq` or `radvd`

#### radvd

Install radvd on your gateway and create `/etc/radvd.conf.tmpl` (which these scripst will use to create radvd.conf) that looks like this:

```
interface __IFACE__
{
   AdvSendAdvert on;
   RDNSS 2001:4860:4860::8888 2001:4860:4860::8844 {};
   prefix __PREFIX__
   {
     AdvOnLink on;
     AdvAutonomous on;
   };
};
```

The scripts will update `__PREFIX__` and `__IFACE__` for you.

#### dnsmasq

Install dnsmasq and create `/etc/dnsmasq.conf.tmpl` *(sample is included in the template - You need to set some params yourself)*

The scripts will replace `__INTERFACES__` and `__PREFIXES__` for you.

## Multiple prefixes

There are 2 ways to support multiple prefixes:

1. The default requests a single /60 and split it up to give one /64 to each interface you specify in your config.
2. If you set SEPARATE_NETS=1 in your config, we will request a /64 for each interface directly from your ISP, assign one to each interface, and cache which lease is which so we can persist that across renewals. The scripts will keep track of this in `/var/lib/dhcp/dhclient-ipv6-mapping`.

## Extra notes:

* You need at least version 4.1.1-P1-17 of isc-dhcp-client (if you're using ISC)
* You need to allow UDP traffic to/from fe80::/10 and to port 546/from port 547 - unless you have `nf_conntrack_dhcpv6` module available and use conntrack.
* These scripts have been tested with Debian/ifup/isc-dhcp-client and both radvd and dnsmasq. Other combinations will probably work with minimal or no tweaking
* See the original blog post that lead to this repo here: https://www.phildev.net/phil/blog/?p=308 for all the gory details.
