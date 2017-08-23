# [This software is not released yet. so, some of the following features are not available right now, but they will be soon. please for now do not use the module in production]

# EASYXEN - Introduction

Easyxen is a custom Ansible Module to automatically manage VM on XEN server hypervisors.
The module include the following features:

- [ ] First xen configuration to enable the ansible module.
		Download images.
		Create log directory.

- [x] Automatically create VM.
- [x] Automatically remove VM.
- [x] Automatically reconfigure VM (change: cpu, ram, disks).
- [X] Provide first OS configuration after boot.
		Remove root ssh login.
		Create auto-sudo user.
		Limit ssh authentication only with key.

- [X] Put userdata during the VM creation. (like AWS)
- [ ] Run playbook after VM creation.
- [ ] Build Images/templates in automation.
- [X] Complete Ansible Integration as a Module and possibility to run the automation without Ansible.
- [X] Save/Version all your infrastructure as a code.
- [ ] Action to check the hypervisor health and usage.
- [X] Reproduce all your private cloud infra automatically.
- [X] Centos 7 VM support
- [ ] Centos 6 VM support
- [ ] Debian 8 VM support
- [ ] Debian 9 VM support
- [ ] Ubuntu 15LTS VM support
- [ ] Ubuntu 16LTS VM support
- [ ] Redhat 6 VM support
- [ ] Redhat 7 VM support
- [ ] Full Python (And compatible with 2.7 and 3.x)

You can find some examples of the usage on the directory /plays/.

## Requirements

- You need to run first the xen_configuration action and then other module actions.
- All the requirements provided by Ansible (such as: SSH open connection and so on.)

#Base image guidelines.

#Contribution.


# Software Architecture and Idea  [DRAFT/IN_PROGRESS]

The idea is to make a completely modular software which will work as a little framework to manage XEN with Bash and/or Python.

So, all the reusable code and functions wil be put in the '/lib/basic.sh', that will work as a container where the other modules and functions will take the 'global' functions.

Indeed, this file contain functions that are used across the various states of the VMs. It is containing functions like:

- Is the virtual machine present?
- Is the exit code ok?
- Log for me this message.
- Is VM deleted?
- Give me the UUID of the virtual machine.
... And Other

The file is written and will be extended in BASH. 
Is automatically laoded in the first phase of the runtime process by the Ansible module entrypoint which is "/easyxen".

This approach allow us to share functions that repeat every time.

As the best practies for Ansible modules every VM have a 'state' which represent how you want your VM (halted, run, absent/removed ...).
Every state work with the 'desidered state' concept, so it will not do any operations if the situation is already as we want.

===========================================================================
© 2017 Isham Araia. EasyXen is released under an MIT-style license; see LICENSE for details.