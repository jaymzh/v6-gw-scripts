# v6-gw-scripts

These are scripts to helpe people setup a v6 gateway on ISPs who hand out a v6 block. They have only been tested with Comcast. See https://www.phildev.net/phil/blog/?p=308 for all the gory details.

## Setup

* Update /etc/sysctl.conf to set:
```
net.ipv6.conf.$YOUR_EXTERNAL_INTERFACE.accept_ra=2
net.ipv6.conf.$YOUR_EXTERNAL_INTERFACE.forwarding=0
```

Replacing `$YOUR_EXTERNAL_INTERFACE` with your external interface.

* Install radvd on your gateway and create `/etc/radvd.conf.tmpl` (which these scripst will use to create radvd.conf) that looks like this:

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

* Drop `dhclient-ipv6` into `/etc/dhcp/dhclient-exit-hooks.d/`

* Drop `99-ipv6` into `/etc/network/if-up.d/` (or your distribution's equivalent)

* Drop `ipv6_prefix_dhclient.conf` in `/etc` and update it to accurately represent your setup.

## Multiple prefix

We now support multiple prefixes. We assume you want one /64 per interface. If you add additional interfaces to the `OTHER_IFACES` variable in `ipv6_prefix_dhclient.conf` then additional prefixes will be requested, and one will be put on each interface. Radvd's configuration will be updated accordingly.

There are a few things to note about multiple prefix support:
* Not all ISPs support requesting more than one. Comcast does, however.
* If you request more than one, but are only getting one, it's because comcast remembers the type of request made with a given DUID and always returns an answer to that same type of request when given the same DUID. You can remove the DUID in your leases file to fix this.
* DHCPv6 will associate an IAID with each prefix and, assuming you keep getting the same prefixes, those IAIDs will be consistent. Therefore `dhclient-ipv6` will keep a mapping of interface we associate-to-IAID so we can always put the right prefix on the right interface. This mapping is kept in `/var/lib/dhcp/dhclient-ipv6-mapping`. I highly recommend not messing with the files in there.

## Extra notes:

* You need at least version 4.1.1-P1-17 of isc-dhcp-client
* You need to allow UDP traffic to/from fe80::/10 and to port 546/from port 547 - unless you have `nf_conntrack_dhcpv6` module available and use conntrack.
