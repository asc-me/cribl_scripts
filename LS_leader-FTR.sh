#! /bin/bash
# env vars
cpu_arch=$(lscpu | grep Architecture: | sed 's/.* //g')
cribl_bin="/opt/cribl/bin"
working_dir="/tmp/ftr"
install_dir="/opt"
#### START: vars to be set by TF code, comment these out for use with Terraform
# logstream vars
cls_user="admin"
cls_pass="password"
cls_leader_ip=$(hostname -I)
cls_leader_port="" ## if left null will use default port
cls_repo_url="" ## if left null will use local git repo only
# git vars
git_user="cribl"
git_email="cribl@cribl.com"
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
repo url: ${cls_repo_url} (will use system local repo if null)
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
firewall-cmd --permanent --zone=public --add-port=10080/tcp # http in port
firewall-cmd --permanent --zone=public --add-port=10420/tcp # tcpjson in port
firewall-cmd --permanent --zone=public --add-port=10000/tcp # splunk2cribl port
firewall-cmd --permanent --zone=public --add-port=4200/tcp # mgmt port
firewall-cmd --permanent --zone=public --add-port=9000/tcp # UI port
systemctl reload firewalld
#### cribl setup
echo "checkpoint: starting git install and setup" | tee -a $working_dir/ftr.log
yum install git -y
sudo -u cribl git config --local user.name $git_user
sudo -u cribl git config --local user.email $git_email
sudo -u cribl git config --global init.defaultBranch main
sudo -u cribl git clone ${cls_repo_url}
# get most recent cribl release from source
#### NOTE: if you dont allow access to public endopints, then you will need to provide a endpoint to fetch the cribl logstream tar from
echo "checkpoint: starting cribl logstream install and setup" | tee -a $working_dir/ftr.log
if [[ $cpu_arch == "x86_64" ]]
then
  curl -Lso - $(curl https://cdn.cribl.io/dl/latest-x64) | tar zxvf -
else
  curl -Lso - $(curl https://cdn.cribl.io/dl/latest-arm64) | tar zxvf -
fi
# move cribl to the install dir and set ownership
mv $working_dir/cribl $install_dir/
cd $install_dir/
chown -R cribl cribl/
# start cribl
echo "starting logstream and adding cribl systemd file" | tee -a $working_dir/ftr.log
sudo -u cribl $cribl_bin/cribl start
$cribl_bin/cribl boot-start enable -m systemd -u cribl
systemctl enable cribl
# perform cribl config
echo "setting up node as leader" | tee -a $working_dir/ftr.log
sudo -u cribl $cribl_bin/cribl mode-master
sudo -u cribl $cribl_bin/cribl restart
