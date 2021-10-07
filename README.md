# Cribl Scripts

## LS_leader-FTR script

How to Use:
- copy script over to box
- update the username and password variables in the script
- add execute permission to the script (chmod +x)
- run the script
- relax

Requirements:
- RHEL based linux
- yum repo access to install git
- epel-release installed

Troubleshooting:
- check the script log in /tmp/ftr/ftr.log
- contact the developer?

## LS_worker-FTR script

How to Use:
- log into your leader node and setup a token in the settings > Distributed Settings > Leader Settings page
- copy script over to box
- update the `cls_leader_ip` and `cls_token` variables in the script
- optional: update the `cls_leader_port` and `cls_worker_group` variables in the script
- add execute permission to the script (chmod +x)
- run the script
- sip tea with pinky out

Requirements:
- RHEL based linux
- epel-release installed
- leader node running with network access from worker node

Troubleshooting:
- check the script log in /tmp/ftr/ftr.log
- contact the developer?