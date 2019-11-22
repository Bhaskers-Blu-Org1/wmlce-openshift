#!/bin/bash
KEY_MOUNT=/wmlce/sshkeys

#workaround to pull in openssh from centos server since ubi does not ship
echo -e "[centos-7-for-power-le-rpms]\n
name = Centos 7 RPMS (RPMs)\n
baseurl = http://mirror.centos.org/altarch/7/os/ppc64le/\n
enabled = 1 \n
gpgkey = http://mirror.centos.org/altarch/7/os/ppc64le/RPM-GPG-KEY-CentOS-7 \n
gpgcheck = 1" > /etc/yum.repos.d/centos.repo
rpm --import http://mirror.centos.org/altarch/7/os/ppc64le/RPM-GPG-KEY-CentOS-7
rpm --import http://mirror.centos.org/altarch/7/os/ppc64le/RPM-GPG-KEY-CentOS-SIG-AltArch-7-ppc64le
yum repolist && yum install -y openssh-server openssh-clients
yum install -y wget perl numactl-libs gtk2 atk cairo gcc-gfortran tcsh libnl3 libmnl tcl tk
wget https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/epel/7/ppc64le/Packages/p/p7zip-plugins-16.02-10.el7.ppc64le.rpm
wget https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/epel/7/ppc64le/Packages/p/p7zip-16.02-10.el7.ppc64le.rpm
rpm -U --quiet p7zip-16.02-10.el7.ppc64le.rpm
rpm -U --quiet p7zip-plugins-16.02-10.el7.ppc64le.rpm
/usr/bin/ssh-keygen -A


if [[ "$INFINIBAND" == "1" ]]; then
  echo -e "* soft memlock unlimited\n* hard memlock unlimited\nroot soft memlock unlimited\nroot hard memlock unlimited" >> /etc/security/limits.conf
fi
#Look for SUDO_USER's home directory since for some reason we're defaulting to root's
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
if [[ -f ${KEY_MOUNT}/id_rsa ]] && [[ ! -f ${USER_HOME}/.ssh/id_rsa ]] ; then
  # Set up ssh
  mkdir -p ${USER_HOME}/.ssh
  cp ${KEY_MOUNT}/id_rsa ${USER_HOME}/.ssh
  chmod 400 ${USER_HOME}/.ssh/id_rsa
  cp ${KEY_MOUNT}/id_rsa.pub ${USER_HOME}/.ssh
  cp ${KEY_MOUNT}/id_rsa.pub ${USER_HOME}/.ssh/authorized_keys
  cat << EOS > ${USER_HOME}/.ssh/config
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
Port $SSH_PORT
EOS
  if grep -q "^Port " /etc/ssh/sshd_config; then
    sed -i "s/^Port .*/Port $SSH_PORT/g" /etc/ssh/sshd_config
  else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  fi
  curr_user=${SUDO_USER}
  [ -z $curr_user ] && curr_user=${USER}
  chown -R ${curr_user} ${USER_HOME}/.ssh
fi
# Start sshd in daemon mode
mkdir -p /var/run/sshd
/usr/sbin/sshd

host=$(hostname)
if [ ${host: -2} = "-0" ]; then
  # Wait for all other workers
  while IFS= read -r host; do
    for n in {1..60}; do
      ssh -o ConnectTimeout=3 -n -q $host exit
      [ $? -eq 0 ] && break
      echo "Retrying ssh connection for host $host..."
      sleep 1
    done
  done < "/wmlce/config/hostfile"
fi
