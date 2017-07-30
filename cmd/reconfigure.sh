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
    sr_name: 'Local storage'  *REQUIRED
    disk_0: 10GiB             *REQUIRED
    disk_1: 200MiB            *Optional (but must be incremental, limit: 12)
    pub_key:                  *REQUIRED
____EOF____
  }

##STARTING WORKFLOW###
#####################################################

	##Check parameters needed for this function.
	##
	check_params \
		'vm_name' \
		'cpu' \
		'ram' \
		'sr_name' \
		'disk_0' \
		'pub_key'
	
	#Get storagege Resource uuid
	sr_uuid=$(xe sr-list name-label="${sr_name}" params=uuid  | awk {'print $5'});
	check_exit \
		"$?" \
		"Get Storage Resource uuid" \
		"Get Storage Resource uuid -> ${sr_uuid}" \
		"fail" \
		"${LINENO}"

	#Check disks param format && \
	#Get desidered disks number
	for n in {0..8}; do
		current_value=$(eval echo "\$disk_${n}");
		if [[ -n "${current_value}" ]]; then
			major_disk="${n}"
		else
			break;
		fi
		
		if [[ $(eval echo "\$disk_${n}") =~ ^[0-9]*GiB$ ]] \
				|| [[ $(eval echo "\$disk_${n}") =~ ^[0-9]*MiB$ ]]; then
			log 'msg' "OK: disk_${n} => ${current_value}"
		else
			log 'exit' "FAIL: disk_${n} => ${current_value} (not right format)"
		fi

		if [[ "${n}" -gt '7' ]]; then
			log "exit" "you're trying to add too much disks."
		fi
	done

	#Rebase start point to 1
	major_disk=$(( ${major_disk} + 1 ))

	#Service messages
	log 'msg' "OK: Desidered ram -> ${ram}"
	log 'msg' "OK: Desidered cpu -> ${cpu}"
	log 'msg' "OK: Desidered disks_number -> ${major_disk}"

	log "msg" "MSG: The action reconfigure could shutdown your machine for a moment"

	##Get vm_uuid by name
	##
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
		grep VDI | 
		wc -l);
	check_exit \
		"$?" \
		"Actual disks number is: ${actual_disks}" \
		"Get actual disks number -> ${actual_disks}" \
		"fail" \
		"${LINENO}"
	
	#Check disks size changes
	if [[ "${major_disk}" -gt "${actual_disks}" ]]; then
		for disk in $(seq 0 ${actual_disks}); do
			echo disk_${disk}
		done
	else
		for disk in $(seq 0 ${major_disk}); do
			echo disk_${disk}
		done
	fi

	##_Perform Shutdown action only \
	##_if something is changed
	if [[ "${actual_ram}" != "${ram}" ]] || \
		[[ "${actual_cpu}" != "${cpu}" ]] || \
		[[ "${actual_disks}" != "${major_disk}" ]]; then
			
			get_vm_current_status=$(xe vm-list uuid=${vm_uuid} \
				params=power-state  | awk {'print $5'});

			#Shutdown the VM if something is changed
			if [[ "${get_vm_current_status}" == "running" ]]; then

				xe vm-shutdown uuid="${vm_uuid}"
				check_exit \
					"$?" \
					"Shutdown VM, ready to be reconfigured." \
					"Shutting down VM." \
					"fail" \
					"${LINENO}"
			fi

			#Setup CPU as the desidered state
			if [[ ${actual_ram} != ${ram} ]]; then
				#Setup RAM value for the new VM.
				xe vm-memory-limits-set uuid="${vm_uuid}" \
				static-min="${ram}MiB" dynamic-min="${ram}MiB" \
				static-max="${ram}MiB" dynamic-max="${ram}MiB" > /dev/null 2>&1
				check_exit \
					"$?" \
					"setup static memory." \
					"setup static memory, value: ${ram}" \
					"fail" \
					"${LINENO}"
			fi

			#Setup CPU as the desidered state
			if [[ ${actual_cpu} != ${cpu} ]]; then
				xe vm-param-set uuid="${vm_uuid}" \
			    VCPUs-at-startup="${cpu}" VCPUs-max="${cpu}" > /dev/null 2>&1
				check_exit \
					"$?" \
					"setup static vCPU." \
					"setup static vCPU: ${cpu}" \
					"fail" \
					"${LINENO}"
			fi


			#REMOVE disks as the desidered state
			if [[ ${actual_disks} -gt ${major_disk} ]]; then
				#Get how many disk we have to remove.
				diff=$(( ${actual_disks} - ${major_disk} ));
				ids=$(seq 0 $(( ${actual_disks} - 1 )) | tail -n ${diff});

				#Print IDs
				for id in ${ids}; do
					if [[ ${id} -gt 2 ]]; then
						device_position=$(( ${id} + 1 ));
					else
						device_position=${id};
					fi

					#Get vbd to remove
					vbd_to_rm=$(xe vm-disk-list uuid=${vm_uuid} | 
							grep "userdevice ( RW): ${device_position}" -B 2 | 
							head -n 1 | 
							awk {'print $5'});

					#Get vbd to remove
					vdi_to_rm=$(xe vbd-list uuid=${vbd_to_rm} params=vdi-uuid | 
						awk {'print $5'});

					#Detroy VBD without any chance to recover it.
					xe vbd-destroy uuid="${vbd_to_rm}"
					check_exit \
						"$?" \
						"Remove VBD ${vbd_to_rm}" \
						"Remove VBD ${vbd_to_rm}" \
						"fail" \
						"${LINENO}"

					#Detroy VDI without any chance to recover it.
					xe vdi-destroy uuid="${vdi_to_rm}"
					check_exit \
						"$?" \
						"Remove VDI ${vdi_to_rm}" \
						"Remove VDI ${vdi_to_rm}" \
						"fail" \
						"${LINENO}"

				done
			fi

			#ADD disks as the desidered state
			if [[ ${actual_disks} -lt ${major_disk} ]]; then
			

				#Get how many disk we have to add.
				diff=$(( ${major_disk} - ${actual_disks} ));
				ids=$(seq 0 $(( ${major_disk} - 1 )) | tail -n ${diff});

				#Print IDs
				for id in ${ids}; do

					#Get virtual_size and device to create VDI
					virtual_size=$(eval echo "\$disk_${id}")

					#Start adding new disks
					log 'msg' "MSG: Adding => disk_${id} | virtualsize => ${virtual_size}";

					xe vm-disk-add \
						disk-size="${virtual_size}" \
						sr-uuid="${sr_uuid}" \
						vm="${vm_uuid}" \
						device="autodetect" > /dev/null 2>&1
					check_exit \
						"$?" \
						"Create VDI on sr ${sr_uuid}." \
						"Create VDI on sr ${sr_uuid}." \
						"fail" \
						"${LINENO}"
				done
			fi

			#Start VM
			##
			 get_vm_current_status=$(xe vm-list uuid=${vm_uuid} \
			 	params=power-state  | awk {'print $5'});
			 if [[ ${get_vm_current_status} == 'halted' ]]; then
			 	echo xe vm-start uuid="${vm_uuid}" > /dev/null 2>&1
			 	check_exit \
			 			"$?" \
			 			"Start VM ${vm_uuid}" \
			 			"Start VM ${vm_uuid}" \
						"fail" \
			 			"${LINENO}"
			fi

		changed=true
		msg="VM ${vm_name} has been reconfigured."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	else
		#No action required, no changes.
		changed=false
		msg="VM ${vm_name} does not require any changes."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
	fi
}