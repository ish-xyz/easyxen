# [-THE MODULE/FRAMEWORK IS NOT RELEASED YET-]

# EASYXEN - Introduction

Easyxen is a custom Ansible Module to automatically manage VM on XEN server hypervisors.

The module include the following feature:

- [x] Create/remove VM.
- [] Reconfigure VM.
- [x] Start/stop VM.
- [] Build templates in automation.
- [] Put userdata during the VM creation. (like AWS)
- [] Running external Ansible Module after the VM creation.
- [] VM hardening via Ansible roles integrated (after the VM is created).
- [] Hypervisor health and usage reports

*THIS SOFTWARE IS NOT RELEASED YET. SO, SOME OF THIS FEATURES ARE NOT
 AVAILABLE RIGHT NOW, BUT THEY WILL BE SOON.

# Framework Requirements

....Soon Available ...

# Framework Usage Guide

....Soon Available ...

# Software Architecture and Idea  [DRAFT/IN_PROGRESS]

The idea is to make a completely modular software which will work as a little framework to manage XEN with Bash and/or Python.

So, all the reusable code and functions wil be put in the '/lib/basic.sh' file that will work as a container where the other modules and functions will take the 'global' functions.

Indeed, this file contain all the functions that are used across the various states of the VMs. It contain functions like:

- Is the virtual machine present?
- Is deleted?
- Give me the UUID of the virtual machine.
... And Other


The file is written and will be extended in BASH.
Is automatically laoded at runtime from the main Ansible module script which is "/easyxen".

===========================================================================

