#!/bin/bash
#
## Basic function of module unirocket
## it provide a set of functions used by 
## the other cmd of the module

function initialize_vars() {
	##Initialize Vars
	## global and non-global

	export STEP=0;
	export ROOT_PATH="/root/easyxen"
	export LOG_FILE="${ROOT_PATH}/log/debug_log";
	export IMAGES_REPO="${ROOT_PATH}/images";
	export DEBUG=1
	#export LOG_TYPE="slack"
}

function vm_exist() {
	##Simple check if the vm passed in 
	##the parameters exist or not
	
    get_vm=$(xe vm-list name-label=$1);
    if [ -n "${get_vm}" ]; then
        return 0
    else
        return 1
    fi
}

function vm_name_available() {
	##Simple check if the vm name passed in 
	##the parameters is available or not

    get_vm_name=$(xe vm-list name-label=$1);
    if [[ -n "${get_vm_name}" ]]; then
        return 1
    else
        return 0
    fi
}

function get_vm_uuid() {
	if [[ -z "$1" ]]; then
		log 'exit' 'Error no vm_name passed'
	else
		vm_uuid_count=$(xe vm-list name-label="$1" params=uuid | awk {'print $5'} | sed '/^\s*$/d' | wc -l);
		if [[ ${vm_uuid_count} -gt 1 ]]; then
			log 'exit' 'Error too much vm match with the same name.'
		else
			vm_uuid=$(xe vm-list name-label="$1" params=uuid | awk {'print $5'} | sed '/^\s*$/d')
			echo "${vm_uuid}"
		fi
	fi
}

function log() {
	## Log function
	## Stdout and append to the ${LOG_FILE} defined in the
	## initialize_vars function.
	if [[ ${DEBUG} == 0 ]]; then
		if [[ "$1" == "msg" ]]; then
			echo "$2" >> "${LOG_FILE}"
		elif [[ "$1" == "exit" ]]; then
			echo "$2 | rc: $3" >> "${LOG_FILE}"
			exit $3
		fi
	else
		if [[ "$1" == "msg" ]]; then
			echo "$2" | tee -a "${LOG_FILE}"
		elif [[ "$1" == "exit" ]]; then
			echo "$2 | rc: $3" | tee -a "${LOG_FILE}"
			exit $3
		fi
	fi
}

function check_exit() {
	## Usage: After a command run --> 
	## check_exit "$?" "{{ success_message }}" "{{ error_message }}" 
	## "fail/warn" "${LINENO}"

	if [[ "$1" == "0" ]]; then
		log 'msg' "OK: $2"
	elif [[ "$4" == "warn" ]]; then
		log 'msg' "WARN: $3"
	elif [[ "$4" == "fail" ]]; then
		log 'exit' "FAIL: $3 exit_code: $5"
	else
		log 'exit' 'You are not using the check_exit function properly.' "${LINENO}"
	fi
}



function check_params() {
	## Function to check parameters 
	## passed as arguments

    for param in ${@}; do
        var_to_check=$(eval echo \$${param});
        if [[ -z "${var_to_check}" ]]; then
                log 'exit' "Param or variables ${param} not specified!" "${LINENO}"
        fi
    done

    if [[ -n "${image}" ]]; then

	    if [[ -f "${IMAGES_REPO}/${image}" ]]; then
	        log 'msg'  'OK: IMAGE exist.';
	    else
	        log 'exit'  'FAIL: IMAGE does not exist.' "${LINENO}";
	    fi
	fi
}

function check_state() {
	##Check if the state exist 
	case "${state}" in
		'absent')
			log "msg" "Operation selected is ${state}"
		;;
		'present')
			log "msg" "Operation selected is ${state}"
		;;
		'halt')
			log "msg" "Operation selected is ${state}"
		;;
		'run')
			log "msg" "Operation selected is ${state}"
		;;
		'reconfigure')
			log "msg" "Operation selected is ${state}"
		;;
		*)
			log "exit" "No operations match." "${LINENO}"
		;;
	esac
}
