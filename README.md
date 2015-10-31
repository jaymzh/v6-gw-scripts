# v6-gw-scripts

These are scripts to helpe people setup a v6 gateway on ISPs who hand out a v6 block. They have only been tested with Comcast. See https://www.phildev.net/phil/blog/?p=308 for all the gorey details.

## Setup

* Update /etc/sysctl.conf to set:
```
net.ipv6.conf.$YOUR_EXTERNAL_INTERFACE.accept_ra=2
net.ipv6.conf.$YOUR_EXTERNAL_INTERFACE.forwarding=0
```

replacing `$YOUR_EXTERNAL_INTERFACE` with your external interface.

* Install radvd on your gateway and create `/etc/radvd.conf.tmpl` (which these scripst will use to create radvd.conf) that looks like this:

```
interface $YOUR_INTERNAL_INTERFACE` with your internal interface.
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

The scripts will update `__PREFIX__` for you.

* Drop `dhclient-ipv6` into `/etc/dhcp/dhclient-exit-hooks.d`

* Drop `99-ipv6` into `/etc/network/if-up.d` (or your distribution's equivalent)

* Drop `ipv6_prefix_dhclient.conf` in `/etc` and update it to accurately represent your setup.


## Extra notes:

* You need at least version 4.1.1-P1-17 of isc-dhcp-client
* You need to allow UDP traffic to/from fe80::/10 and to port 546/from port 547 - unless you have `nf_conntrack_dhcpv6` module available and use conntrack.
