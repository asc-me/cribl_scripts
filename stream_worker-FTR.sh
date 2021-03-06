#! /bin/bash
# env vars
cpu_arch=$(lscpu | grep Architecture: | sed 's/.* //g')
cribl_bin="/opt/cribl/bin"
working_dir="/tmp/ftr"
install_dir="/opt"
#### START: vars to be set by TF code, comment these out for use with Terraform
# logstream vars
cls_worker_group="default" ## only change this if you want to adde this worker to a specific group
cls_leader_ip="0.0.0.0" ## MUST be changed to your leader's ip/url
cls_leader_port="9000" ## only change if leader UI/API access is changed from default port
stream_token="" ## MUST be changed to your leader's distributed mgmt token (see readme for more info)
#### END: vars to be set by TF
# make working directory
rm -rf $working_dir
mkdir $working_dir
cd $working_dir
#### environment setup
timestamp=$(date)
sudo tee $working_dir/ftr.log > /dev/null << EOT
starting script at: $timestamp
checkpoint: vars check
CPU Arch: $cpu_arch
leader ip: ${cls_leader_ip}
leader port: ${cls_leader_port} (will use app default if null)
worker group: ${cls_worker_group} (will use system local repo if null)
checkpoint: vars check complete
EOT
# create cribl local user
echo "checkpoint: editing local user and system limits" | tee -a $working_dir/ftr.log
adduser cribl
# disable THP
sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
sudo echo never > /sys/kernel/mm/transparent_hugepage/defrag
# set file ulimits for splunk
sudo tee /etc/security/limits.d/20-cribl.conf > /dev/null <<EOT
cribl    hard    nproc   40000
cribl    soft    nproc   40000
cribl    hard    fsize    unlimited
cribl    soft    fsize    unlimited
cribl    hard    nofile    80000
cribl    soft    nofile    80000
EOT
# firewalld port access for services
echo "adding firewall rules" | tee -a $working_dir/ftr.log
firewall-cmd --permanent --zone=public --add-port=10080/tcp # http in port
firewall-cmd --permanent --zone=public --add-port=10420/tcp # tcpjson in port
firewall-cmd --permanent --zone=public --add-port=10000/tcp # splunk2cribl port
firewall-cmd --permanent --zone=public --add-port=4200/tcp # mgmt port
firewall-cmd --permanent --zone=public --add-port=9000/tcp # UI port
systemctl reload firewalld
# bootstrap cribl instance from leader node
echo "Bootstrapping worker from leader API" | tee -a $working_dir/ftr.log
curl "http://${cls_leader_ip}:${cls_leader_port}/init/install-worker.sh?group=${cls_worker_group}&token=${stream_token}" | bash -

sudo -u cribl /opt/cribl/bin/cribl mode-worker -H ${cls_leader_ip} -p ${cls_leader_port} -u ${stream_token}