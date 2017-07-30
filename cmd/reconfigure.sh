#!/bin/bash
#
## Function to Reconfigure the VM HW on XEN hypervisors
##
#################################################

function reconfigure() {
	##Reconfigure virtual machines (Idempotent)
	##NOTE: The Shrink function will be not released in the first version of the module.

	#Initialize Variables
	TMPFILE001=$(echo "/tmp/${RANDOM}.easyxen");
	TMPFILE002=$(echo "/tmp/${RANDOM}.easyxen");
	TMPFILE003=$(echo "/tmp/${RANDOM}.easyxen");

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
    disk_0: 10GiB             *Optional (default value= 10GiB)
    disk_1: 200MiB            *Optional (default value= 10GiB)
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
		'pub_key'
	
	#Get storagege Resource uuid
	sr_uuid=$(xe sr-list name-label="${sr_name}" params=uuid  | awk {'print $5'});
	check_exit \
		"$?" \
		"Get Storage Resource uuid" \
		"Get Storage Resource uuid -> ${sr_uuid}" \
		"fail" \
		"${LINENO}"
	
	##Get vm_uuid by name
	##
	vm_uuid=$(get_vm_uuid "${vm_name}");
	check_exit \
		"$?" \
		"Get vm uuid by name" \
		"Get vm uuid by name" \
		"fail" \
		"${LINENO}"	
	
	#Check Disks desidered state
	disks=$(printenv | grep disk_[0-8] | grep -v '^disk_3=');
	act_disks="${TMPFILE001}"
	des_disks="${TMPFILE002}"

	xe vm-disk-list uuid="${vm_uuid}"  | grep userdevice | 
		awk {'print $4'} | sort > "${act_disks}";
	check_exit \
		"$?" \
		"Get actual disks position." \
		"Get actual disks position." \
		"fail" \
		"${LINENO}"

	printenv | grep disk_[0-8] | grep -v '^disk_3=' | 
		awk -F 'disk_' {'print $2'} | 
		awk -F '=' {'print $1'} | sort > "${des_disks}"
	check_exit \
		"$?" \
		"Get desidered disks position." \
		"Get desidered disks position." \
		"fail" \
		"${LINENO}"	

	#Get disks to remove and add.
	disks_to_add=$(diff "${act_disks}" "${des_disks}" | grep -e '>' | awk {'print $2'});
	disks_to_rmv=$(diff "${act_disks}" "${des_disks}" | grep -e '<' | awk {'print $2'});
	
	#Check disks format values
	for x in $(cat ${des_disks}); do
		curvalue=$(eval echo \$disk_${x});
		
		if [[ "${curvalue}" =~ ^[0-9]*[G,M]iB$ ]]; then
			log 'msg' "OK: The disk_${x} => ${curvalue}, value is valid.";
		else
			log 'exit' "FAIL: The disk_${x} => ${curvalue}, value is not valid.";
		fi
	done


	#Check disks size changes & get disks to update later.
	for disk in ${disks}; do

		#Current Disk ID and Value
		cd_id=$(echo ${disk} | awk -F '=' {'print $1'});
		cur_dev=$(echo ${cd_id} | awk -F '_' {'print $2'});
		cd_value=$(echo ${disk} | awk -F '=' {'print $2'});
		cur_vbd=$(xe vm-disk-list uuid=${vm_uuid} | 
			grep "userdevice ( RW): ${cur_dev}" -B 2 | 
			grep 'uuid ( RO)' | 
			awk {'print $5'} | 
			head -n 1);
		if [[ -n "${cur_vbd}" ]]; then

			#Current VDI
			cur_vdi=$(xe vbd-list params=vdi-uuid uuid=${cur_vbd} | 
				awk {'print $5'});

			#Current virtual size
			cur_vs=$(xe vdi-list uuid="${cur_vdi}" params=virtual-size | 
				awk {'print $5'});

			if [[ "${cd_value}" =~ ^[0-9]*GiB$ ]]; then
				cur_ds=$(( $(echo ${cd_value} | 
					sed 's#GiB##g') * 1024 * 1024 * 1024 ));
			elif [[ "${cd_value}" =~ ^[0-9]*MiB$ ]]; then
				cur_ds=$(( $(echo ${cd_value} | 
					sed 's#MiB##g') * 1024 * 1024 ));
			fi

			#Check if the desidered size is higher then di current.
			if [[ "${cur_ds}" -gt "${cur_vs}" ]]; then
				disk_size_changes=true
				log 'msg' "MSG: Detected disk size changes on ${cd_id} to ${cur_ds}"
				echo "${cur_dev} ${cd_value}" >> "${TMPFILE003}";
			fi

		fi
	done

	#=Service messages
	if [[ -n "${disk_3}" ]]; then
		log 'msg' 'WARN: DISK POSITION 3 WILL BE IGNORED.'
	fi

	log 'msg' 'MSG: Shrink operation on disks will be ignored.'
	log 'msg' 'MSG: Disks over 8 as position will be ignored.'
	log 'msg' "MSG: Desidered ram -> ${ram}"
	log 'msg' "MSG: Desidered cpu -> ${cpu}"
	log 'msg' "MSG: Desidered disks -> $(printenv | 
		grep disk_[0-8] | 
		grep -v '^disk_3=' | wc -l)"

	log "msg" "MSG: The action 'reconfigure' may be turn off your VM for a moment."
	#= End Service messages

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
	
	
##_Perform Shutdown action only \
	##_if something is changed
	if [[ "${actual_ram}" != "${ram}" ]] || \
		[[ "${actual_cpu}" != "${cpu}" ]] || \
		[[ -n "${disks_to_rmv}" ]] || \
		[[ -n "${disks_to_add}" ]] || \
		[[ "${disk_size_changes}" == true ]]; then
			
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
				VCPUs-at-startup=1 VCPUs-max="${cpu}" > /dev/null 2>&1
			    check_exit \
					"$?" \
					"Pair static vCPU." \
					"Pair static vCPU: ${cpu}" \
					"fail" \
					"${LINENO}"

			    VCPUs-at-startup="${cpu}" VCPUs-max="${cpu}" > /dev/null 2>&1
				check_exit \
					"$?" \
					"setup static vCPU." \
					"setup static vCPU: ${cpu}" \
					"fail" \
					"${LINENO}"
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

			#ADD disks
			log 'msg' 'MSG: Start analyzing the disks to add...'
			for dpos in ${disks_to_add}; do
				cur_size=$(eval echo \$disk_${dpos});
				xe vm-disk-add uuid="${vm_uuid}" device="${dpos}" disk-size="${cur_size}" sr-uuid="${sr_uuid}"
				check_exit \
			 		"$?" \
			 		"Add disk ${dpos} with size => ${cur_size} on sr ${sr_uuid}." \
			 		"Add disk ${dpos} with size => ${cur_size} on sr ${sr_uuid}." \
					"fail" \
			 		"${LINENO}"
			done

			#REMOVE disks
			log 'msg' 'MSG: Start analyzing the disks to remove...'
			for dpos in ${disks_to_rmv}; do
				xe vm-disk-remove device="${dpos}" uuid="${vm_uuid}"
				check_exit \
			 		"$?" \
			 		"Remove disk on position ${dpos} from sr ${sr_uuid}." \
			 		"Remove disk ${dpos} from sr ${sr_uuid}." \
					"fail" \
			 		"${LINENO}"
			done
			
			#RESIZE disks
			log 'msg' 'MSG: start resizing disks if is needed.'
			cat "${TMPFILE003}" | while read l; do
				cur_dev=$(echo $l | awk {'print $1'});
				cur_ds=$(echo $l | awk {'print $2'});

				cur_vbd=$(xe vm-disk-list uuid=${vm_uuid} | 
					grep "userdevice ( RW): ${cur_dev}" -B 2 | 
					grep uuid | 
					head -n1 | 
					awk {'print $5'});
				cur_vdi=$(xe vbd-list uuid="${cur_vbd}" params=vdi-uuid | 
					awk {'print $5'});
				
				xe vdi-resize uuid="${cur_vdi}" disk-size="${cur_ds}" > /dev/null 2>&1
				check_exit \
			 		"$?" \
			 		"Resize disk ${dev} from vdi ${cur_vdi}." \
			 		"Resize disk ${dev} from vdi ${cur_vdi}." \
					"fail" \
			 		"${LINENO}"
				#Resize action
			done

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