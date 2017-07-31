function halt() {
	##Halt virtual machines (Idempotent)
	##

	function ansible_usage() {
    	#Usage function, help
		cat <<____EOF____
- name: "Xen Turn off VM"
  easyxen:
    state: halt  					#* REQUIRED
    vm_name: easyxen_worker1 		#* REQUIRED

____EOF____
	}

##STARTING WORKFLOW###
#####################################################

	#Check parameters needed for this function.
	#(the function check_params is in lib/basic.sh)
	check_params 'vm_name'

	#Check if the vm is prensent
	#If NOT it will be fail.
	vm_exist "${vm_name}"
	if [[ $? == 0 ]]; then

		#Check if the VM is already shutted down.
		vm_uuid=$(get_vm_uuid "${vm_name}");
		vm_power_state=$(xe vm-list params=power-state uuid=${vm_uuid} | awk {'print $5'} | sed '/^\s*$/d');
		if [[ "${vm_power_state}" == 'halted' ]]; then

			#Log and Ansible(JSON) output (Desidered State no change)
			log 'msg' "VM ${vm_name} already halted."
			changed=false
			msg="VM ${vm_name} already halted."
			printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"

		else
			#Shutting down the VM using xen-cli
			halt_vm=$(xe vm-shutdown uuid="${vm_uuid}");
			check_exit \
				"$?" \
				"Shutting down virtual machine ${vm_name}" \
				"Shutting down ${vm_name} ${vm_uuid}" \
				"fail" \
				"${LINENO}"

			#Log and Ansible(JSON) output (Desidered State change)
			log 'msg' "VM ${vm_name} halted."
			changed=true
			msg="VM ${vm_name} halted."
			printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
		fi
	else
		#ERROR if the VM does not exist.
		log 'exit' 'The desidered vm does not exist.'
	fi
}