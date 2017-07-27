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
    state: reconfigure
    vm_name: {{ vm_name }}    *REQUIRED
    cpu: 1                    *REQUIRED
    ram: 1024                 *REQUIRED
    disk_0: 20                *REQUIRED
    disk_1: 10                *Optional (but must be incremental, limit: 12)
    pub_key:                  *REQUIRED
____EOF____
  }

##STARTING WORKFLOW###
#####################################################

	#Check parameters needed for this function.
	check_params \
		'vm_name' \
		'cpu' \
		'ram' \
		'disk_0'

	for n in {0..12}; do
		current_value=$(eval echo "\$disk_${n}");
		if [[ -n "${current_value}" ]]; then
			major_disk="${n}"
		fi
	done

	log "msg" "The action reconfigure could shutdown your machine for a moment"

	##Get vm_uuid by name
	vm_uuid=$(get_vm_uuid "${vm_name}");
	check_exit \
		"$?" \
		"Get vm uuid by name" \
		"Get vm uuid by name" \
		"fail" \
		"${LINENO}"

	##Get actual values CPU
	actual_cpu=$(xe vm-param-get uuid=${vm_uuid} param-name=VCPUs-max);
	check_exit \
		"$?" \
		"Actual CPU value is: ${actual_cpu}" \
		"Get actual CPU -> ${actual_cpu}" \
		"fail" \
		"${LINENO}"

	##Get actual values RAM
	actual_ram=$(( $(xe vm-list params=memory-static-max uuid=${vm_uuid} |
		awk {'print $5'} | sed '/^\s*$/d') / 1024 / 1024 ));
	check_exit \
		"$?" \
		"Actual RAM value is: ${actual_cpu}" \
		"Get actual RAM value -> ${actual_cpu}" \
		"fail" \
		"${LINENO}"

	##Get actual values DISKS N
	actual_disks=$(xe vm-disk-list uuid=${vm_uuid} |
		grep userdevice  | rev |
		awk {'print $1'} | rev |
		sort  | tail -n 1);
	check_exit \
		"$?" \
		"Actual disks number is: ${actual_disks}" \
		"Get actual disks number -> ${actual_disks}" \
		"fail" \
		"${LINENO}"
	exit
	##Check disks size
	for x in $(seq 0 ${major_disk}); do
		cur_disk_size=$(( $(xe vm-disk-list uuid="${vm_uuid}" | 
			grep "${x} VDI:" -A 4 | 
			grep 'virtual-size' | 
			awk {'print $4'}) / 1024 / 1024 / 1024 ));
		desidered_size=$(eval echo "\$disk_${x}");
		echo $
	done

	##Shutdown action
	if [[ ${actual_ram} != ${ram} ]] || \
		[[ ${actual_cpu} != ${cpu} ]] || \
		[[ ${actual_disks} != ${major_disk} ]]; then
			xe vm-shutdown uuid="${vm_uuid}"
			check_exit \
				"$?" \
				"Get vm uuid by name" \
				"Get vm uuid by name" \
				"fail" \
				"${LINENO}"
	else
		#No action required, no changes.
		changed=false
		msg="VM ${vm_name} does not require any changes."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	fi
}