# nosu-buildimage
**NOSU (NOS Ubuntu)** is an unofficial flavour of Ubuntu OS, that is specifically made
for network devices (switches, routers) supporting [Linux Switchdev drivers](https://www.kernel.org/doc/Documentation/networking/switchdev.txt). 

This repo contains set of scripts which produce an installable binary image (ONIE installer) build for NOSU.

### Prerequisites
- docker
- docker-compose

### Usage

* Clone this repo: `git clone https://github.com/switchdev-nos/nosu-buildimage`
* `cd nosu-buildimage`
* `./build.sh env/default`
* NOSU ONIE image will be placed in: `./image/`
