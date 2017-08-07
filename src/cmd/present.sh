function present() {
	##Create VM and setup as the desidered state. (Non-Idempotent)
	##

	#Initialize variables
	retry_temptative=0
	count=0
	vgflag="vgroot"
    mount_point="/mnt/$vm_name";
    mount_dev="/dev/${vgflag}/root";
    tmp_pass="easyxen${RANDOM}${RANDOM}${RANDOM}";
   
    function ansible_usage() {
    	#Usage function, help
		cat <<____EOF____
- hosts: target
  connection: ssh
  become: true
  tasks:
    - name: "Xen create new machine"
      easyxen:
        state: present                              #*REQUIRED
        vm_name: easyxen_worker1                    #*REQUIRED
        cpu: 1                                      #*REQUIRED
        ram: 512                                    #*REQUIRED
        mac_address: 00:0c:29:6f:5d:c3              #(optional) - default = automatically generated
        image: centos_7.xva                         #*REQUIRED
        ip_address: 192.168.1.170                   #*REQUIRED
        gateway: 192.168.1.1                        #*REQUIRED
        netmask: 255.255.255.0                      #(optional) - default = 255.255.255.0
        broadcast: 192.168.1.255                    #(optional) - default = {{ ip_address }}.255
        dns1: 192.168.1.126                         #(optional) - default = 8.8.8.8
        dns2: 192.168.1.127                         #(optional) - default = 8.8.4.4
        disk_position: 0                            #*REQUIRED disk_position of the disk to mount to configure the network and other base configuration.
        distro: centos                              #*REQUIRED
        network_file: '{network_path}/ifcfg-eth0'   #(optional) - default defined by OS distro.
        pub_key:  ssh-rsaAxxizu..roo@github.com     #*REQUIRED
        os_user: "{{vm_user}}"                      #(optional) - default = easyxen
        userdata:									#(optional) - default = none
          x: y
          opts: 1
          param: arg
____EOF____
	}
	
	function cleanup() {
		if [[ $1 != 0 ]]; then
			case "$2" in

				'plug')
					xe vbd-destroy uuid="${new_vbd_uuid}";
					;;

				'plug')
					xe vbd-destroy uuid="${new_vbd_uuid}";
					;;

				'kpartx')
					xe vbd-unplug uuid="${new_vbd_uuid}";
					xe vbd-destroy uuid="${new_vbd_uuid}";
					;;

				'vgchange')
					/sbin/kpartx -fd "/dev/${device}" > /dev/null 2>&1
					xe vbd-unplug uuid="${new_vbd_uuid}";
					xe vbd-destroy uuid="${new_vbd_uuid}";
					;;

				'mount')
					vgchange -an "${vgflag}" --config global{metadata_read_only=0} > /dev/null 2>&1
					rmdir "${mount_point}/"
					/sbin/kpartx -fd "/dev/${device}" > /dev/null 2>&1
					xe vbd-unplug uuid="${new_vbd_uuid}";
					xe vbd-destroy uuid="${new_vbd_uuid}";
					;;

				*)
					log "msg" "Cleanup called, but nothing to do."
					;;
			esac
		fi
	}

	function configure_network_centos() {
echo -ne \
"DEVICE=eth0\n\
BOOTPROTO=none\n\
ONBOOT=yes\n\
USERCTL=no\n\
IPV6INIT=no\n\
PEERDNS=no\n\
DNS1=${dns1}\n\
DNS2=${dns2}\n\
TYPE=Ethernet\n\
NETMASK=${netmask}\n\
IPADDR=${ip_address}\n\
GATEWAY=${gateway}\n\
HWADDR=${mac_address}\n\
ARP=yes" > "${mount_point}${network_file}";

		echo "$vm_name" > "${mount_point}/etc/hostname"
		echo "127.0.0.1 $vm_name" >> "${mount_point}/etc/hosts"

	}


	function configure_network_ubuntu() {
		log 'msg' "No configuration found for distro: ${distro}"
	}


	function configure_network_redhat() {
		echo -ne \
"DEVICE=eth0\n\
BOOTPROTO=none\n\
ONBOOT=yes\n\
USERCTL=no\n\
IPV6INIT=no\n\
PEERDNS=no\n\
DNS1=${dns1}\n\
DNS2=${dns2}\n\
TYPE=Ethernet\n\
NETMASK=${netmask}\n\
IPADDR=${ip_address}\n\
GATEWAY=${gateway}\n\
HWADDR=${mac_address}\n\
ARP=yes" > "${mount_point}${network_file}";

		echo "$vm_name" > "${mount_point}/etc/hostname"
		echo "127.0.0.1 $vm_name" >> "${mount_point}/etc/hosts"
	}


	function configure_network_debian() {
		log 'msg' "No configuration found for distro: ${distro}"
	}

##STARTING WORKFLOW###
#####################################################


	################################
	####== START FIRST CHECKS ==####
	################################

	#Check parameters needed for this function.
	#(the function check_params is in lib/basic.sh)
	check_params \
		'vm_name' \
		'cpu' \
		'ram' \
		'gateway' \
		'ip_address' \
		'disk_position' \
		'distro' \
		'pub_key' \
		'os_user' \
		'image'


	#Setting up all optional variables with the default value.

	#DNS default are google dns 8.8.8.8/8.8.4.4
	[[ -z "${dns1}" ]] && dns1='8.8.8.8'
	[[ -z "${dns2}" ]] && dns1='8.8.4.4'

	#Netmask default is /24
	[[ -z "${netmask}" ]] && netmask='255.255.255.0'

	#Network file to the network configuration on the guest.
	[[ -z "${network_file}" ]] && \
		case "${distro}" in
			'centos')
				network_file='/etc/sysconfig/network-scripts/ifcfg-eth0'
			;;

			'redhat')
				network_file='/etc/sysconfig/network-scripts/ifcfg-eth0'
			;;

			'ubuntu')
				network_file='/etc/network/interfaces'
			;;

			'debian')
				network_file='/etc/network/interfaces'
			;;

			*)
				log 'exit' 'No default configuration found for the current VM' "${LINENO}"
			;;
		esac
		

	#After the machine is configured (halt or run, default=run)
	[[ -z "${after_configuration}" ]] && \
		after_configuration="run"
	
	#Default Broadcast addr is .255
	[[ -z "${broadcast}" ]] && broadcast=$(echo ${ip_address} | 
		awk -F '.' {'print $1"."$2"."$3".255"'})

	#Default mac_address is {RANDOM}
	[[ -z "${mac_address}" ]] && \
		mac_address=$( echo $(uuidgen | sed 's/\-//g' | 
			cut -c 1-12 | fold -w 2) | sed 's# #:#g');

	#Check if the vm_name is available for this hypervisor.
	vm_name_available "${vm_name}"
	check_exit \
		"$?" \
		"vm_name available" \
		"vm_name not available" \
		"fail" \
		"${LINENO}"

	####################################
	####== IMPORT VM AND HW SETUP ==####
	####################################

	#Import vm and get the uuid
	vm_uuid=$(xe vm-import filename="${IMAGES_REPO}/${image}");
	check_exit \
		"$?" \
		"vm import done." \
		"vm import fail." \
		"fail" \
		"${LINENO}"

	#Rename VM as the desidered state
	xe vm-param-set uuid="${vm_uuid}" name-label="${vm_name}";
	check_exit \
		"$?" \
		"vm rename done." \
		"vm rename failed." \
		"fail" \
		"${LINENO}"

	#Setup vCPU value for the new VM.
	xe vm-param-set uuid="${vm_uuid}" \
    VCPUs-at-startup="1" VCPUs-max="${cpu}"

    xe vm-param-set uuid="${vm_uuid}" \
    VCPUs-at-startup="${cpu}" VCPUs-max="${cpu}";
	check_exit \
		"$?" \
		"cpu setup done." \
		"cpu setup failed, not mandatory." \
		"warn" \
		"${LINENO}"

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

	#Remove all old VIF
	old_vifs=$(xe vif-list vm-uuid="${vm_uuid}" params=uuid  | 
		awk {'print $5'} | sed '/^\s*$/d');

	for vif_uuid in ${old_vifs[@]}; do
		xe vif-destroy uuid="${vif_uuid}"
		check_exit \
			"$?" \
			"Remove old virtual interfaces..."
			"Remove old virtual interface ${vif_uuid}"
			"fail"
			"${LINENO}"
	done

	#Get network uuid
	network_uuid=$(xe network-list bridge=xenbr0 params=uuid |
		awk {'print $5'} | grep .);
	check_exit \
		"$?" \
		"Get UUID of the xenbr0 interface." \
		"Get UUID of the xenbr0 interface." \
		"fail" \
		"${LINENO}"
    
    VIF=$(xe vif-create vm-uuid=${vm_uuid} \
        mac=${mac_address} \
        device=1 \
        network-uuid=${network_uuid});
	check_exit \
		"$?" \
		"Create new network virtual interface" \
		"Create new network virtual interface with mac_address ${mac_address}" \
		"fail" \
		"${LINENO}"


	###############################
	####== MOUNT GUEST DISKS ==####
	###############################

	#Get the dom0 UUID
    dom0_uuid=$(xe vm-list is-control-domain=true params=uuid | 
        awk {'print $5'});
	check_exit \
		"$?" \
		"Get dom0 uuid." \
		"Get dom0 uuid. " \
		"fail" \
		"${LINENO}"

	#Get correct vdi_uuid based on device position --> 0
	vbd_uuids=$(xe vbd-list vm-uuid="${vm_uuid}" params=uuid |
	                awk {'print $5'} | sed '/^\s*$/d');

	for vbd_uuid in ${vbd_uuids[@]}; do
	## For each vbd get the VDI device position
	        device_position=$(xe vbd-param-list uuid=${vbd_uuid} |
	        	grep userdevice | awk {'print $4'});

	        ## If the position is 0, get the 
	        ## vdi uuid and save it.
	        if [[ ${device_position} == ${disk_position} ]]; then
	                vdi_uuid=$(xe vbd-list uuid=${vbd_uuid} params=vdi-uuid |
	                        awk {'print $5'} | sed '/^\s*$/d')
					check_exit \
						"$?" \
						"Get vm vdi_uuid." \
						"Get vm vdi_uuid." \
						"fail" \
						"${LINENO}"
	        fi
	done

	#Create new vbd on the dom0 for the guest vdi
    new_vbd_uuid=$(xe vbd-create vm-uuid=${dom0_uuid} \
        vdi-uuid=${vdi_uuid} device=autodetect);
	check_exit \
		"$?" \
		"Create new vbd on dom0 with the guest vdi." \
		"new_vbd_uuid: vdi --> ${vdi_uuid}, dom0 --> ${dom0_uuid}}" \
		"fail" \
		"${LINENO}"

    xe vbd-plug uuid="${new_vbd_uuid}"
    rc=$?
    cleanup "${rc}" 'plug'
    check_exit \
		"${rc}" \
		"Plug new vbd." \
		"Plug new vbd. new_vbd_uuid --> ${new_vbd_uuid}" \
		"fail" \
		"${LINENO}"

	device=$(xe vbd-list uuid="${new_vbd_uuid}" params=device |
		awk {'print $5'} | sed '/^\s*$/d');
    rc=$?
    cleanup "${rc}" 'kpartx'
	check_exit \
		"$?" \
		"Get disk device to setup." \
		"Get disk device to setup." \
		"fail" \
		"${LINENO}"

	#Wait until the vgroot flag is the only one in the system.
	vg_exist=$(vgs | awk {'print $1'} | grep -w "${vgflag}")
    while [[ -n "${vg_exist}" ]]; do
        log 'msg' 'Waiting to the VG'
        sleep 3
        retry_temptative=$(( ${retry_temptative} + 1));

        if [[ ${retry_temptative} == 10 ]]; then
        	cleanup "${rc}" 'kpartx'
	    	check_exit \
				"1" "null" \
				"vgroot flag not available. \
				Too much build or locked situation." \
				"fail" \
				"${LINENO}"
        fi
    done

    #Partx new device
    kpartx_device=$(/sbin/kpartx -fva /dev/${device});
    rc=$?
    cleanup "${rc}" 'kpartx'
    check_exit \
		"${rc}" \
		"kpartx disk device" \
		"kpartx device ${device}" \
		"fail" \
		"${LINENO}"

	#Activate the volume group of the guest disk
	vgchage_device=$(vgchange -ay "${vgflag}" \
		--config global{metadata_read_only=0})
	rc=$?
	cleanup "${rc}" 'vgchange'
	check_exit \
		"${rc}" \
		"vgchage: activate guest volume group" \
		"vgchage: activate guest volume group" \
		"fail" \
		"${LINENO}"

	#Mount Guest Logical Volume on mnt/vm_name/
	mkdir "${mount_point}/";
	mount "${mount_dev}" "${mount_point}/"
	rc=$?
	cleanup "${rc}" 'mount'
	check_exit \
		"${rc}" \
		"mount ${mount_dev} ${mount_point}/" \
		"mount ${mount_dev} ${mount_point}/" \
		"fail" \
		"${LINENO}"

	###########################################
	####== GUEST BASIC OS CONFIGURATIONS ==####
	###########################################

	#Guest disk is now mounted:
	#Starting network configuration
	case "${distro}" in
		'centos')
			configure_network_centos
			;;
		'redhat')
			configure_network_redhat
			;;
		'debian')
			configure_network_debian
			;;
		'ubuntu')
			configure_network_ubuntu
			;;
		*)
			log 'exit' "The selected distro ${distro} doesnt have any network configuration" "{LINENO}" 
			;;
	esac

	#Setup Shadow file for TEMP root login
	tmp_pass_shadow=$(python -c "import crypt; print crypt.crypt(\"${tmp_pass}\")")
	shadow_string="root:${tmp_pass_shadow}::0:99999:7:::"

	#Setup shadow with the tmp password for root
	##
	chmod 644 "${mount_point}/etc/shadow" && \
	tac "${mount_point}/etc/shadow" | grep . --color=none | \
		head -n -1 > "${mount_point}/etc/shadow.new" && \
	echo "${shadow_string}" >> "${mount_point}/etc/shadow.new" && \
	tac "${mount_point}/etc/shadow.new" | grep . --color=none > "${mount_point}/etc/shadow" && \
	chmod 600 "${mount_point}/etc/shadow"
	rc=$?
	cleanup "${rc}" 'mount'
	check_exit \
		"${rc}" \
		"Setup /etc/shadow." \
		"Setup /etc/shadow." \
		"fail" \
		"${LINENO}"

	#Disable Selinux
	##
	sed -i 's#enforcing#disabled#g' "${mount_point}/etc/selinux/config"
	rc=$?
	cleanup "${rc}" 'mount'
	check_exit \
		"${rc}" \
		"Disable selinux." \
		"Disable selinux -> ${mount_point}/etc/selinux/config" \
		"fail" \
		"${LINENO}"

	#Import UserData
	##
	if [[ -n "${userdata}" ]]; then
		touch "${mount_point}/etc/userdata"
		check_exit \
			"${rc}" \
			"Create userdata file. ${mount_point}/etc/userdata" \
			"Create userdata file. ${mount_point}/etc/userdata" \
			"fail" \
			"${LINENO}"

		echo "${userdata}" >> "${mount_point}/etc/userdata"
		check_exit \
			"${rc}" \
			"Import userdata file in ${mount_point}/etc/userdata" \
			"Import userdata file in ${mount_point}/etc/userdata" \
			"fail" \
			"${LINENO}"
	fi

	###############################
	####== UMOUNT GUEST DISK ==####
	###############################

	#Starting: umount guest disk and remove dom0 link
	umount "${mount_point}/" &&  rmdir "${mount_point}/"
	check_exit \
		"$?" \
		"umount & rm directory -> ${mount_point}/" \
		"umount & rm directory -> ${mount_point}/" \
		"fail" \
		"${LINENO}"

	#Deactivate Logical Volume and Volume group
    vgchange -an "${vgflag}" --config global{metadata_read_only=0} > /dev/null 2>&1
    check_exit \
		"$?" \
		"vgchange deactivate volumgroup" \
		"vgchange deactivate volumgroup" \
		"fail" \
		"${LINENO}"

	#Kpartx -d (remove partitioning on device)
    /sbin/kpartx -dv "/dev/${device}" > /dev/null 2>&1
    check_exit \
		"$?" \
		"Remove partitioning on device, ${device}" \
		"Remove partitioning on device, ${device}" \
		"fail" \
		"${LINENO}"
    
    xe vbd-unplug uuid="${new_vbd_uuid}" && \
    xe vbd-destroy uuid="${new_vbd_uuid}"
	check_exit \
		"$?" \
		"unnplug and destroy the new_vbd ${new_vbd_uuid}" \
		"unnplug and destroy the new_vbd ${new_vbd_uuid}" \
		"fail" \
		"${LINENO}"
	
	#Setup VM description
	xe vm-param-set \
	name-description="$ip_address#$mac_address" \
	uuid="${vm_uuid}"
    check_exit \
		"$?" \
		"Setup new name ${vm_uuid}" \
		"unnplug and destroy the new_vbd ${new_vbd_uuid}" \
		"fail" \
		"${LINENO}"

	##########################################
	####== LAST OPERATIONS AND START VM ==####
	##########################################

	#Rename disks with vm_name and disk position
    for vdi_uuid in $(xe vbd-list vm-uuid=${vm_uuid} | grep -v "not in database" | grep "vdi-uuid ( RO):" | awk {'print $4'}); do
        xe vdi-param-set name-label="${vm_name}#${count}" uuid="${vdi_uuid}";
        count=$(( ${count} + 1 ));
    done
    
    #Start and halt VM to attach the os customization
    xe vm-start uuid="${vm_uuid}" > /dev/null 2>&1
    check_exit \
		"$?" \
		"Start VM to take the OS configuration." \
		"Start VM to take the OS configuration." \
		"fail" \
		"${LINENO}"

	log 'msg' "temporary password => ${tmp_pass}"
	log 'msg' "sshpass -p \"${tmp_pass}\" ssh -l root \"${ip_address}\" \
	\"adduser --password 'xyz' --shell /bin/bash -m -c 'Easyxen Automation' ${os_user} && \
		mkdir /home/${os_user}/.ssh && touch /home/${os_user}/.ssh/authorized_keys && \
		echo ${pub_key} > /home/${os_user}/.ssh/authorized_keys && \
		chmod 600 /home/${os_user}/.ssh/authorized_keys && \
		sed -i 's/#PermitRootLogin yes/#PermitRootLogin no/g' /etc/ssh/sshd_config && \
		sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && \
		echo \\"${os_user}  ALL=NOPASSWD: ALL\\" >> '/etc/sudoers' && \
		chown -R ${os_user}:${os_user} /home/${os_user}/.ssh/\""

	sshpass -p "${tmp_pass}" ssh -l root "${ip_address}" \
	"adduser --password 'xyz' --shell /bin/bash -m -c 'Easyxen Automation' ${os_user} && \
		mkdir /home/${os_user}/.ssh && touch /home/${os_user}/.ssh/authorized_keys && \
		echo ${pub_key} > /home/${os_user}/.ssh/authorized_keys && \
		chmod 600 /home/${os_user}/.ssh/authorized_keys && \
		sed -i 's/#PermitRootLogin yes/#PermitRootLogin no/g' /etc/ssh/sshd_config && \
		sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && \
		echo \"${os_user}  ALL=NOPASSWD: ALL\" >> '/etc/sudoers' && \
		chown -R ${os_user}:${os_user} /home/${os_user}/.ssh/"
    check_exit \
		"$?" \
		"Configure OS guest user and security basics." \
		"Configure OS guest user and security basics." \
		"fail" \
		"${LINENO}"

	##Success output to integrate with Ansible
	changed=true
    msg="ip address: ${ip_address}"
    printf '{"changed": %s, "msg": "%s"}' "${changed}" "${msg}"
}