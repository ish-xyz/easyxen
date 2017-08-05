function xen_conf() {
	##Reconfigure virtual machines (Idempotent)
	##NOTE: The Shrink function will be not released in the first version of the module.

	#Initialize Variables
	#NONE=NONE

	function ansible_usage() {
  #Usage function, help
    cat <<____EOF____
- name: "Reconfigure XEN VM."
  easyxen:
    state: xen_conf
____EOF____
  }

		#No action required, no changes.
		changed=false
		msg="Xen configuration is compliant."
		printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
}