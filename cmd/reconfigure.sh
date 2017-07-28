#!/bin/bash
#
## Function to Reconfigure the VM HW on XEN hypervisors
##
#################################################

function reconfigure() {
	##Reconfigure virtual machines (Idempotent)
	##NOTE: The Shrink function will be not released in the first version of the module.

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
		'disk_0' \
		'pub_key'

	for n in {0..12}; do
		current_value=$(eval echo "\$disk_${n}");
		if [[ -n "${current_value}" ]]; then
			major_disk="${n}"
		fi
	done
	log "msg" "OK: Desidered values are: ram -> ${ram} | cpu -> ${cpu} | disk_number -> ${major_disk}"
	log "msg" "MSG: The action reconfigure could shutdown your machine for a moment"

	##Get vm_uuid by name
	vm_uuid=$(get_vm_uuid "${vm_name}");
	check_exit \
		"$?" \
		"Get vm uuid by name" \
		"Get vm uuid by name" \
		"fail" \
		"${LINENO}"

	##Get actual values CPU
	##
	actual_cpu=$(xe vm-param-get uuid=${vm_uuid} param-name=VCPUs-max);
	check_exit \
		"$?" \
		"Actual CPU value is: ${actual_cpu}" \
		"Get actual CPU -> ${actual_cpu}" \
		"fail" \
		"${LINENO}"

	##Get actual values RAM
	##
	actual_ram=$(( $(xe vm-list params=memory-static-max uuid=${vm_uuid} |
		awk {'print $5'} | sed '/^\s*$/d') / 1024 / 1024 ));
	check_exit \
		"$?" \
		"Actual RAM value is: ${actual_ram}" \
		"Get actual RAM value -> ${actual_ram}" \
		"fail" \
		"${LINENO}"

	##Get actual values DISKS N
	##
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

	##Check disks size
	##
	for x in $(seq 0 ${major_disk}); do
		raw_size=$(xe vm-disk-list uuid="${vm_uuid}" | 
			grep "${x} VDI:" -A 4 | 
			grep 'virtual-size' | 
			awk {'print $4'});

		if [[ -n ${raw_size} ]]; then
			cur_disk_size=$(( ${raw_size} / 1024 / 1024 / 1024 ));
			desidered_size=$(eval echo "\$disk_${x}");
			if [[ "${desidered_size}" -gt "${cur_disk_size}" ]]; then
				disk_size_changes=true
			fi
		else
			disk_size_changes=true
		fi
	done

	##Perform Shutdown action only \
		##if something is changed
	if  [[ ${actual_ram} != ${ram} ]] || \
		[[ ${actual_cpu} != ${cpu} ]] || \
		[[ ${actual_disks} != ${major_disk} ]] || \
		[[ ${disk_size_changes} == true ]] ; then
			
			get_vm_current_status=$(xe vm-list uuid=${vm_uuid} \
				params=power-state  | awk {'print $5'});
			if [[ "${get_vm_uuid}" == 'running' ]]; then
				#Shutdown the VM.
				xe vm-shutdown uuid="${vm_uuid}"
				check_exit \
					"$?" \
					"Shutdown VM, ready to be reconfigured." \
					"Shutting down VM." \
					"fail" \
					"${LINENO}"
			fi

			[[ ${actual_ram} != ${ram} ]] && \
				#Setup RAM value for the new VM.
				xe vm-memory-limits-set uuid="${vm_uuid}" \
				static-min="${ram}MiB" dynamic-min="${ram}MiB" \
				static-max="${ram}MiB" dynamic-max="${ram}MiB"
				check_exit \
					"$?" \
					"setup static memory." \
					"setup static memory, value: ${ram}" \
					"fail" \
					"${LINENO}"
		
			[[ ${actual_cpu} != ${cpu} ]] && \
				#Setup vCPU value for the new VM.
				xe vm-param-set uuid="${vm_uuid}" \
			    VCPUs-at-startup="${cpu}" VCPUs-max="${cpu}"
				check_exit \
					"$?" \
					"setup static vCPU." \
					"setup static vCPU: ${cpu}" \
					"fail" \
					"${LINENO}"

			if [[ ${actual_disks} -gt ${major_disk} ]]; then
				
				#Get how many disk we have to remove.
				diff=$(( ${actual_disks} - ${major_disk} ));
				ids=$(seq 0 "${major_disk}" | tail -n ${diff});

				#Print IDs
				for id in ${ids}; do
					echo ${id};
				done
			fi

			if [[ ${actual_disks} -lt ${major_disk} ]]; then

				#Get how many disk we have to add.
				diff=$(( ${major_disk} - ${actual_disks} ));

			fi

	else
		#No action required, no changes.
		changed=false
		msg="VM ${vm_name} does not require any changes."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	fi
}