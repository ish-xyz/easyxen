function main() {
	#Main function to run all the module automation
	initialize_vars
	check_state
	check_exit \
		"$?" \
		"Check&Get parameter 'state'." \
		"Check&Get parameter 'state' ${state}" \
		"fail" \
		"${LINENO}"

	#Include the selected operation.
	#If not exist ERROR
	check_func_state=$(type "${state}" |head -n1 | awk {'print $4'});
	if [[ "${check_func_state}" == "function" ]]; then
		${state}
	else
		log 'exit' 'State is incorrect';
	fi	
}

main
