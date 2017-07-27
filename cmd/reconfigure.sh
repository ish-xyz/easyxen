#!/bin/bash
#
## Function to Reconfigure the VM HW on XEN hypervisors
##
#################################################

function reconfigure() {
	##Reconfigure virtual machines (Idempotent)
	##

	function ansible_usage() {
    	#Usage function, help
		cat <<____EOF____
- name: "Reconfigure XEN vm."
  easyxen:
    vm_name: {{ vm_name }}
    cpu: 1
    ram: 1024
    disks:
      - position: 0
        size: 20G
       	label: "{{ vm_name }}_disk_0"

____EOF____
	}

  

}