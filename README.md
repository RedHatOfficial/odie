```
   :sdMMMMMMMMNMNMh:     +mMMMNNNNNds         :NMMMh    .dMMMMMMNMMMMMM
 `hMMMMMMMmdhhhhydMMm\  .MMMN+hddddmNNMd+     hMMMMMs   dMMMMMAMMMMMMMMM
 sMMMMN/        \MMMMN  /MMMm   ``-+dMMMMd    dMMMMMM.  NMMMM
 hMMMMM          MMMMM  sMMMM       oMMMMM/   NMMMMMM+  MMMMMNNNN
 mMMMMM          MMMMM  sMMMM        dMMMM+  .MMMMMMMo  MMMMMMMd
 NMMMMM          MMMMM  sMMMM       -mMNMM-  -MMMMMMMo  NMMMM/
 yMNmMN\        /MMMMd  :MMMM      mMhydMy   `MMMMMMM:  dMMMn
 `dMy/MMMMMNNNNNNMMMN/   MMMMNdhyss+odMMo     yMMMMMm   +MMMMMNMMMMMMMMM
   :shNMMMMMMMMNmlo/     `hmNMNNMMMNds/       `hMMMN    `MMhdmM<<Nmmddd

 OpenShift (Container Platform) Disconnected installer (for) Enterprises!
```

ODIE is a distribution of OpenShift Container Platform (OCP) and Red Hat Enterprise Linux (RHEL) on custom media for installation into environments without access to the internet. These environments often are segregated the enterprise network and may lack other common services necessary for an OCP installation.  The result of an ODIE installation is a full fledged OCP cluster including container images from supplemental products - RHOCS, RHOAR, SCL, xPaaS, and ohers.

The key features include:

* Drop-in Installation - ODIE can autonomously provisioned into a ready environment without user intervention
* Batteries Included - all services needed for a disconnected OCP cluster are provisioned during initial setup:
  * DNS
  * DHCP
  * TFTP (PXE booting)
  * NTP
  * rsyslogd
  * httpd server - hosting yum repository
  * Container image registry
* Curated lists of RPM and container image contents - reliable, easy-to-use scripts to download specific images and minimize media size
* User-friendly OCP configuration - To ease the installation burden on administrators that are unfamiliar with OCP/Ansible.  ODIE provides an opinionated step-by-step installation using a CSV host configuration and autogenerated YAML property files.  The output is a generated OCP advanced install inventory file that you can modify or just provide your own inventory file.
* Spinning! - lots of time staring at installation is improved with patented SkunkDog spinning technology and improved log display

> Long term it is expected to migrate onto other solutions, such as Red Hat Satellite to manage RPMs and Red Hat Quay for disconnected image registry.  Please discuss migration strategies with your Red Hat sales team.

## Demo

- setup

This function configures the

The configuration files in /opt/odie/config have been generated. 


Entire build process

- Build

- Deployment


# Usage

## Installation - CD Boot

# Build Overview

## Media Overview

ODIE produces
The baseline ODIE ISO is designed to be burned onto a 4.7GB single layer DVD (our testing identified a significant coaster rate when attempting to boot on dual layer media).

Different ISOs:
* *baseline* - This contains all RPMs and the minimal set of container images that are necessary produces a single ISO that contains everything necessary to install a base installation OpenShift Container Platform.  This disc is bootable when burned with the necessary flags.
* *extras* - Contains additional OCP services require the supplemental disc.
* *runtimes* - Base application frameworks and containers including most of Red Hat's images from Software Collection Libraries, Source-to-Images, Red Hat JBoss.

There is also a *mega* ISO which is bootable and contains the full set of content.  This is approximately 16GB and can be added onto a USB stick or Bluray disc.  Of course, you could also transfer the file through the network.  The script `stage-iso.sh` simplifies the usage of these ISO files without burning.
Build

> `--deploy`  will automatially execute the deploy.sh sript

### Initial Environment Setup

* Generate the base build.yml configuration file
```
./odie.sh properties build.yml
```

* Upload the RHEL 7 ISO to the location defined in `/opt/odie/config/build.yml (this needs to be a user readable directory)

```
rhel_iso: /root/rhel-server-7.5-x86_64-dvd.iso
```

* Register with the Red Hat Network

```
sudo subscription-manager register
```

* Obtain the pool id for your account and attach it to the subscription

```
subscription-manager list --available --pool-only | less
```

> Red Hat associates should add `--matches='Employee SKU'` to limit the list.  This can take a while.


* Find your appropriate pool containing "Red Hat OpenShift Container Platform" and capture the pool id.  If you do not see this, you will need the appropriate entitlements added to your account.  Contact your sales rep for additional infomation.



### Build and Deploy

```
./build.sh --clean -full --baseline --release --deploy

```

While this is building we can setup 



### KVM Configuration for ODIE Lab

This doc assumes you have an existing lab setup with virt-manager installed. To get started with a local instance of ODIE, you will manually set up KVM networking & storage, and then run Ansible playbooks to deploy and configure ODIE on your lab box.

This wiki assumes you have installed the "Virtualization Host" package group and virt-manager, virt-install, git and ansible packages. You should also have allocated enough storage space to hold the virtual machines.

Open virt-manager and run the following commands:

```
Edit -> Connection Details
  Virtual Networks
    Delete default
    Click [+] to “Create a new virtual network”
      Network Name: virbr1 # virbr0 is used by KVM's "default" network
      [Forward]
      Ensure “Enable IPv4 network address space definition” is checked
      Network: 192.168.124.0/24
      Uncheck “Enable DHCPv4”
      [Forward]
      [Forward]
      Ensure “Isolated virtual network” is selected
      DNS Domain Name: lab.odie
      [Finish]
Edit -> Connection Details
  [ Add Pool]
    Add a New Storage Pool
    Name: ODIE
    [Forward]
    Type: dir Filesystem Directory
      Choose target directory
      Create a new folder: /opt/odie/vm-images
Edit -> Preferences
  Polling
    Check:
      Poll CPU usage
      Poll Disk I/O
      Poll Network I/O
      Poll Memory stats
```



## Manifests

### RPM


The files manifest/base-rpms.txt.processed and manifest/base-rpms.txt.packages define the explicit packages used in a given release.  This allows for build reproducibility across a specific tag.  Performing a *--clean* will delete these files.  Generation of this manifest will take a couple hours.


ODIE uses a Makefile for its build process.  A wrapper script is used to set some variables 

This is

### Images
