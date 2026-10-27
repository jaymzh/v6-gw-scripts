# IPv6 Gateway Scripts

[![Lint](
https://github.com/jaymzh/v6-gw-scripts/actions/workflows/lint.yml/badge.svg
)](https://github.com/jaymzh/v6-gw-scripts/actions/workflows/lint.yml)

These are scripts to help people set up a v6 gateway on ISPs who support
requesting IPv6 blocks via DHCPv6.

These scripts have been tested on both Comcast/Xfinity and GFiber/Webpass.

I've only tested these on Debian, but they should work on Fedora-derived
distributions as well.

## Prerequisites

You will need a DHCP client that can run scripts on leases. We support the ISC
DHCP client (`isc-dhcp-client` on Debian/Ubuntu) and `dhcpcd` (see
[dhcpcd](#dhcpcd) below), though the ISC client is what's been tested most.

You will also need some Router Advertisement daemon - we support `radvd` or
`dnsmasq` (though I recommend `radvd`).

With the ISC client and the default `SEPARATE_NETS=0`, you will also need
`python3`, which is used to split up the prefix.

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

Copy it to the right location, and make sure it's executable:

* For `ifup`, that's `/etc/network/if-up.d/`
* For `NetworkManager`, that's `/etc/NetworkManager/dispatcher.d/` (though
  these scripts have not been tested with NM). It must be owned by root and
  not group- or world-writable, and `NetworkManager-dispatcher.service` must
  be enabled.
* For `systemd-networkd`, there's no direct equivalent. Something like
  `networkd-dispatcher` could run it, but `99-ipv6` doesn't currently
  understand the variables it passes, so it would need adapting.

On systemd machines, `99-ipv6` starts the DHCP client in its own transient
unit, `dhclient6-<iface>` or `dhcpcd6-<iface>`, so you can find its logs with
`journalctl -u dhclient6-<iface>`. If `/etc/network/ip6tables` exists and is
executable, `99-ipv6` will also run `/etc/network/ip6tables reload` to reload
your firewall rules.

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
  # Request a /63 and give a /64 from it to eth0 and eth2
  ia_pd 2/::/63 eth0/0/64 eth2/1/64
```

Because of this, `SEPARATE_NETS` and `REQUEST_ADDRESS` don't apply when using
dhcpcd; use `ia_pd` and `ia_na` instead. If you already have an
`/etc/dhcpcd.exit-hook`, source `dhclient-ipv6` from it instead of replacing
it.

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
scripts will use to create `/etc/radvd.conf`, overwriting whatever is there)
that looks like this:

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

Install dnsmasq and create `/etc/dnsmasq.conf.tmpl`, which these scripts will
use to create `/etc/dnsmasq.conf` (overwriting whatever is there). Start from
the [sample](dnsmasq.conf.tmpl.sample) in this repo; you'll need to set some
options, such as the IPv4 ones, yourself.

The scripts will replace `__INTERFACES__` and `__PREFIXES__` for you.

## Multiple prefixes

With the ISC client, there are 2 ways to support multiple prefixes (with
dhcpcd, use `ia_pd` in `dhcpcd.conf` instead):

1. The default requests a single prefix just big enough to give one /64 to
   each interface you specify in your config (a /64 for 1 interface, a /63
   for 2, a /62 for 3 or 4, and so on), and splits it up between them. Set
   `PREFIX_LEN_HINT` to ask for a specific size instead, e.g. `60`. This is
   only a hint: your ISP may give you something bigger or smaller, and if
   it's too small, the interfaces that don't fit won't get a prefix.
2. If you set `SEPARATE_NETS=1` in your config, we will request a /64 for each
   interface directly from your ISP, assign one to each interface, and cache
   which lease is which so we can persist that across renewals. The scripts
   will keep track of this in `/var/lib/dhcp/dhclient-ipv6-mapping`.

## Gateway address

By default, in addition to the prefix(es), we also request a single address
for the gateway itself (a DHCPv6 IA_NA), which dhclient assigns to your
external interface. Set `REQUEST_ADDRESS=0` in your config to disable this.
With dhcpcd, add `ia_na` to `dhcpcd.conf` instead.

If you turn this on when you already have a lease, your ISP may refuse to add
an address when dhclient renews that lease ("no addrs" in the logs), and only
hand one out for a fresh request. To force one without losing your DUID (and
likely your prefix), stop dhclient, cut the lease file
(`/var/lib/dhcp/dhclient6.<iface>.leases`) down to just its `default-duid`
line, and start it again.

## Extra notes

* You need at least version 4.1.1-P1-17 of isc-dhcp-client (if you're using
  ISC)
* You need to allow UDP traffic to/from fe80::/10 and to port 546/from port
  547, unless you have the `nf_conntrack_dhcpv6` module available and use
  conntrack.
* These scripts have been tested with Debian/ifup/isc-dhcp-client and both
  radvd and dnsmasq. Other combinations will probably work with minimal or no
  tweaking.
* See the original [blog post](https://www.phildev.net/phil/blog/?p=308) that
  led to this repo.
