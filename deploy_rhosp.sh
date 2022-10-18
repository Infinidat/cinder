#!/bin/bash
set -o pipefail

. stackrc 

if [ "$1" == "--redeploy" ]; then
openstack overcloud delete overcloud -y
sleep 10;
openstack baremetal node delete rhosp-cmp01; openstack baremetal node delete rhosp-cmp02; openstack baremetal node delete rhosp-ctl01

openstack overcloud node import nodes.yaml
sleep 120;
timeout 600 openstack overcloud node introspect --all-manageable
sleep 120
openstack baremetal node provide --wait 600 rhosp-ctl01
openstack baremetal node provide --wait 600 rhosp-cmp01
openstack baremetal node provide --wait 600 rhosp-cmp02
sleep 10

openstack baremetal node set --property capabilities='profile:compute,boot_mode:uefi' rhosp-cmp01
openstack baremetal node set --property capabilities='profile:compute,boot_mode:uefi' rhosp-cmp02
openstack baremetal node set --property capabilities='profile:control,boot_mode:uefi' rhosp-ctl01
openstack baremetal node set --deploy-interface='direct' rhosp-cmp01
openstack baremetal node set --deploy-interface='direct' rhosp-cmp02
openstack baremetal node set --deploy-interface='direct' rhosp-ctl01
fi;

sudo test -f /var/lib/mistral/multipath.conf || sudo cp multipath.conf /var/lib/mistral
sudo diff -uN multipath.conf /var/lib/mistral/multipath.conf || cat multipath.conf | sudo tee /var/lib/mistral/multipath.conf
sudo chmod 0644 /var/lib/mistral/multipath.conf
sudo chown 42430:42430 /var/lib/mistral/multipath.conf

openstack overcloud deploy --templates \
  -e /usr/share/openstack-tripleo-heat-templates/environments/multipathd.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/cinder-backup.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services/barbican.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/barbican-backend-simple-crypto.yaml \
  -e /home/stack/templates/cinder-infinidat-config.yaml \
  -e /home/stack/custom-undercloud-params.yaml \
  -e /home/stack/containers-prepare-parameter.yaml \
  --stack overcloud \
  --log-file overcloud_hl_$(date +%d%m%Y%H%M%S).log | tee -a overcloud_deployment_$(date +%d%m%Y%H%M%S).log
