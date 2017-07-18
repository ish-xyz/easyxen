#!/bin/bash
#
## Function to remove VMs on XEN hypervisors
##
#################################################

function absent() {
	##Remove virtual machines (Idempotent)
	##

	function usage() {
    	#Usage function, help
		cat <<____EOF____
- name: "Xen Remoev VM"
  easyxen:
    state: absent 			* REQUIRED
    vm_name: worker2 		* REQUIRED

____EOF____
	}

##STARTING WORKFLOW###
#####################################################

	#Check parameters needed for this function.
	#(the function check_params is in lib/basic.sh)
	check_params 'vm_name'

	#Check if the vm is prensent
	#If NOT is already in the desidered state.
	vm_exist "${vm_name}"
	if [[ $? == 0 ]]; then
		vm_uuid=$(get_vm_uuid "${vm_name}");

		vm_power_state=$(xe vm-list params=power-state uuid=${vm_uuid} | awk {'print $5'} | sed '/^\s*$/d');
		if [[ "${vm_power_state}" == 'halted' ]]; then
			remove_vm=$(xe vm-destroy uuid="${vm_uuid}");
			check_exit \
				"$?" \
				"Removing virtual machine ${vm_name}" \
				"Removing vm ${vm_name} ${vm_uuid}" \
				"fail" \
				"${LINENO}"
		else
			remove_vm=$(xe vm-shutdown uuid="${vm_uuid}" force=true && \
			xe vm-destroy uuid="${vm_uuid}");
			check_exit \
				"$?" \
				"Removing virtual machine ${vm_name}" \
				"Removing vm ${vm_name} ${vm_uuid}" \
				"fail" \
				"${LINENO}"
		fi

		#Log and Ansible(JSON) output
		changed=true
		msg="VM ${vm_name} removed."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	else
		#Log and Ansible(JSON) output
		log 'msg' 'vm already removed.'
		changed=false
		msg="VM already removed."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	fi
}