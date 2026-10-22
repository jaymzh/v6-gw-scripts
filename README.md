# IPv6 Gateway Scripts

[![Lint](
https://github.com/jaymzh/v6-gw-scripts/actions/workflows/lint.yml/badge.svg
)](https://github.com/jaymzh/v6-gw-scripts/actions/workflows/lint.yml)

These are scripts to helpe people setup a v6 gateway on ISPs who support
requestiong IPv6 blocks via DHCPv6.

These scripts have been tested on both Comcast/Xfinity and GFiber/Webpass.

I've only tested these on Debian, but they should work on Fedora-derived
distributions as well.

## Prerequisites

You will need a DHCP client that can run scripts on leases. Both the ISC DHCP
client (`isc-dhcp-client` on Debian/Ubuntu) and `dhcpcd` on Fedora/RHEL/CentOS
should work, though I've only tested these with ISC's client.

You will also need some Router Advertisement daemon - we support `radvd` or
`dnsmasq` (though I recommend `radvd`).

## Setup

### Configuration

Start by creating a config file. All scripts in this repo read
`/etc/ipv6_prefix_dhclient.conf`, a file in shell format. See the [sample
ipv6_prefix_dhclient.conf](ipv6_prefix_dhclient.conf) for a list of all
supported variables and a description of what they do.

### IPv6 hook for your network stack

The first step is to install the `99-ipv6` hook script into the relevant place
for your network manager. This script is what fires off the DHCPv6 request when
your interface comes up. It handles requesting the right number and size of
block based on your configuration.

Copy it to the right location:

* For `ifup`, that's `/etc/network/if-up.d/`
* For `NetworkManager`, that's `/etc/NetworkManager/dispatcher.d/` (though
  these scripts have not been tested with NM). Make sure
  `NetworkManager-dispatcher.service` is enabled.
* For `systemd-networkd`, you'll have to use something like
  `networkd-dispatcher`, but that has not been tested at all.

Note that you should *NOT* let your network stack configure IPv6 on its
own, that will conflict with these scripts. That means:

* For `ifup` do *not* set an `inet6` entry
* For NetworkManager, tell it to ignore IPv6 on all interfaces:
  `nmcli connection modify <conn> ipv6.method ignore` (run for each `<conn>`)

### Configuration hook for your DHCP client

Once you have your addresses, this hook will update the addresses on the
relevant interface(s) (when needed) and update your `radvd` or `dnsmasq`
configuration with the relevant addresses.

Copy `dhclient-ipv6` to the relevant location for your DHCP client:

* For ISC dhclient this is `/etc/dhcp/dhclient-exit-hooks.d/`
* For dhcpcd, copy it to `/etc/dhcpcd.exit-hook` (a file, not a directory)

#### dhcpcd

If you use dhcpcd, set `DHCP_CLIENT="dhcpcd"` in your config. dhcpcd
requests the prefix and assigns it to your internal interfaces itself, so
the hook only updates your RA daemon config. Tell dhcpcd what to request and
where to put it in `/etc/dhcpcd.conf`, for example:

```text
interface eth1
  ipv6rs
  # Optional: an address for the gateway itself
  ia_na 1
  # Request a /60 and give a /64 from it to eth0 and eth2
  ia_pd 2/::/60 eth0/0/64 eth2/1/64
```

`99-ipv6` starts a per-interface `dhcpcd -6` on your external interface, so
don't also have the system-wide dhcpcd service managing it.

Alternatively, if dhcpcd is already what manages your external interface (i.e.
you're not using `ifup` or `NetworkManager` for it), skip `99-ipv6` and just
configure the system-wide `dhcpcd`. Ensure it doesn't also try to configure
your internal interfaces.

### RA Daemon

These scripts can support `radvd` or `dnsmasq`.

#### radvd

Install radvd on your gateway and create `/etc/radvd.conf.tmpl` (which these
scripts will use to create radvd.conf) that looks like this:

```text
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

Install dnsmasq and create `/etc/dnsmasq.conf.tmpl` *(sample is included in the
template - You need to set some params yourself)*

The scripts will replace `__INTERFACES__` and `__PREFIXES__` for you.

## Multiple prefixes

There are 2 ways to support multiple prefixes:

1. The default requests a single /60 and split it up to give one /64 to each
   interface you specify in your config.
2. If you set SEPARATE_NETS=1 in your config, we will request a /64 for each
   interface directly from your ISP, assign one to each interface, and cache
   which lease is which so we can persist that across renewals. The scripts
   will keep track of this in `/var/lib/dhcp/dhclient-ipv6-mapping`.

## Extra notes:

* You need at least version 4.1.1-P1-17 of isc-dhcp-client (if you're using
  ISC)
* You need to allow UDP traffic to/from fe80::/10 and to port 546/from port 547
  - unless you have `nf_conntrack_dhcpv6` module available and use conntrack.
* These scripts have been tested with Debian/ifup/isc-dhcp-client and both
  radvd and dnsmasq. Other combinations will probably work with minimal or no
  tweaking
* See the original [blog post](https://www.phildev.net/phil/blog/?p=308) that
  lead to this repo.
