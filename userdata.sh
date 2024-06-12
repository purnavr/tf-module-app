#!/bin/bash

cd /etc/yum.repos.d/

sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*

sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

ansible-pull -i localhost -U https://github.com/purnavr/roboshop-ansible.git roboshop.yml -e role_name=${component} -e env=${env} >/opt/ansible.log