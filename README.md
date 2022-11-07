# Documentation

 - [RedHat OpenStack Platform 16.2 Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/director_installation_and_usage/index)
 - [OpenStack documentation](https://docs.openstack.org/cinder/train/configuration/block-storage/drivers/infinidat-volume-driver.html)

# Infinidat Infinibox storage deployment Guide for RHOSP 16.2

## Overview

This page provides detailed steps on how to enable the containerized Infinidat cinder driver for RedHat OpenStack Platform.
It also contains steps to deploy & configure Infinidat Infinibox backends for RedHat OpenStack Platform 16.2.

The custom Cinder container image contains following packages:

- infinisdk
- capacity
- infi.dtypes.wwn

## Prerequisites

* Red Hat OpenStack Platform 16.2 with RedHat Enterprise Linux 8.2.

* Infinidat Infinibox storage 4.0 or higher.

## Steps

### 1.	Prepare the Environment Files for Infinidat cinder backend in cinder-volume container

#### 1.1 Environment File for cinder-volume container

To use Infinidat Infinibox as a block storage back end, cinder-volume container should be deployed.

Procedure

Generate a default environment file that prepares images using your Satellite server as a source.
Refer to an official RedHat OpenStack 16.2 deployment guide (Chapter: [3.16. Preparing a Satellite server for container images](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html/director_installation_and_usage/assembly_preparing-for-director-installation#proc_preparing-a-satellite-server-for-container-images_preparing-for-director-installation)) point 9

Edit the "containers-prepare-parameter.yaml" file.

Add an exclude parameter to the strategy for the main Red Hat OpenStack Platform 16.2 cinder container image. 

```
parameter_defaults:
  ContainerImagePrepare:
    - push_destination: true
      excludes:
        - cinder-volume
      set:
        namespace: registry.redhat.io/rhosp-rhel8
        name_prefix: openstack-
        name_suffix: ''
        tag: 16.2
        ...
      tag_from_label: "{version}-{release}"
```

Check the [example "containers-prepare-parameter.yaml" file](https://github.com/Infinidat/cinder/blob/doc/rhosp16.2/examples/containers-prepare-parameter.yaml) from our repository.

Add a new strategy to the ContainerImagePrepare parameter that includes the replacement container image for the Infinidat Infinibox cinder plugin:

```
parameter_defaults:
  ContainerImagePrepare:
    ...
    - push_destination: true
      includes:
        - cinder-volume
      set:
        namespace: registry.connect.redhat.com/infinidat
        name_prefix: openstack-
        name_suffix: -infinidat-plugin
        tag: latest
        ...
```
Check the [example "containers-prepare-parameter.yaml" file](https://github.com/Infinidat/cinder/blob/doc/rhosp16.2/examples/containers-prepare-parameter.yaml) from our repository.

Configure the authentication for the redhat registires at the ContainerImageRegistryCredentials parameter:
Refer to Refer to an official RedHat OpenStack 16.2 deployment guide (Chapter: [3.9. Obtaining container images from private registries](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html/director_installation_and_usage/assembly_preparing-for-director-installation#ref_obtaining-container-images-from-private-registries_preparing-for-director-installation))

Use the "containers-prepare-parameter.yaml" file with any deployment commands, such as as openstack overcloud deploy:

```
openstack overcloud deploy --templates
    ...
    -e containers-prepare-parameter.yaml
    ...
```

When director deploys the overcloud, the overcloud uses the Infinidat cinder container image instead of the standard cinder container image.

#### 1.2 Environment File for cinder backend

The Infindiat Infinibox environment file for RedHat OpenStack Platform contains the settings for each backend you want to define.

Create the environment file "cinder-infinidat-config.yaml" with below parameters and other backend details.

```
parameter_defaults:
  CinderEnableIscsiBackend: false
  CinderEnableRbdBackend: false
  CinderEnableNfsBackend: false
  NovaEnableRbdBackend: false
  CinderDefaultVolumeType: infinidat-iscsi1
  CinderRpcResponseTimeout: 180
  NovaLibvirtVolumeUseMultipath: true
  MultipathdEnable: true
  MultipathdCustomConfigFile: /var/lib/mistral/multipath.conf
  ControllerExtraConfig:
    cinder::config::cinder_config:
      infinidat-iscsi1/volume_driver:
        value: cinder.volume.drivers.infinidat.InfiniboxVolumeDriver
      infinidat-iscsi1/volume_backend_name:
        value: infinidat-iscsi1
      infinidat-iscsi1/san_ip:
        value: infinibox.domain.com
      infinidat-iscsi1/san_login:
        value: your_san_login
      infinidat-iscsi1/san_password:
        value: your_san_password
      infinidat-iscsi1/san_thin_provision:
        value: true
      infinidat-iscsi1/driver_use_ssl:
        value: true
      infinidat-iscsi1/suppress_requests_ssl_warnings:
        value: true
      infinidat-iscsi1/infinidat_pool_name:
        value: rhsop_cinder_pool1
      infinidat-iscsi1/infinidat_storage_protocol:
        value: iscsi
      infinidat-iscsi1/infinidat_iscsi_netspaces:
        value: default_iscsi_space
      infinidat-iscsi1/san_thin_provision:
        value: true
      infinidat-iscsi1/use_multipath_for_image_xfer:
        value: true
      infinidat-iscsi1/image_volume_cache_enabled:
        value: false
```

Check the [example "cinder-infinidat-config.yaml" file](https://github.com/Infinidat/cinder/blob/doc/rhosp16.2/examples/cinder-infinidat-config.yaml) from our repository.

#### Additional Help

For further details of Infinidat Infinibox storage cinder driver configuration, refer to an official OpenStack documentation [Chapter: INFINIDAT InfiniBox Block Storage driver](https://docs.openstack.org/cinder/train/configuration/block-storage/drivers/infinidat-volume-driver.html)

### 2.	Deploy the overcloud and configured backends

After creating the "cinder-infinidat-config.yaml" environment file with appropriate backends, deploy the backend configuration by running the openstack overcloud deploy command using the templates option.

```
openstack overcloud deploy --templates
    ...
    -e cinder-infinidat-config.yaml
    ...
```

The order of the environment files (.yaml) is important as the parameters and resources defined in subsequent environment files take precedence.

```
openstack overcloud deploy --templates \
    ...
    -e /home/stack/templates/cinder-infinidat-config.yaml \
    -e /home/stack/containers-prepare-parameter.yaml \
    ...
    --stack overcloud \
    --log-file overcloud_hl_$(date +%d%m%Y%H%M%S).log | tee -a overcloud_deployment_$(date +%d%m%Y%H%M%S).log
```

### 3.	Verify the configured changes

3.1	SSH to controller node from undercloud and check the docker process for cinder-volume
```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ sudo podman ps | grep cinder
e7192ba6663c  rhosp-director-ng.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-api:16.2                  kolla_start           3 weeks ago   Up 27 hours ago                cinder_api
4b2b34c038c0  rhosp-director-ng.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-api:16.2                  kolla_start           3 weeks ago   Up 27 hours ago                cinder_api_cron
b8e45cae61fb  rhosp-director-ng.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-scheduler:16.2            kolla_start           3 weeks ago   Up 27 hours ago                cinder_scheduler
54cc3b7449fa  rhosp-director-ng.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-backup:16.2               kolla_start           3 weeks ago   Up 27 hours ago                cinder_backup
dc20a77daeee  cluster.common.tag/openstack-cinder-volume-infinidat-plugin:pcmklatest                             /bin/bash /usr/lo...  26 hours ago  Up 26 hours ago                openstack-cinder-volume-podman-0
```

3.2.	Verify that the infinisdk python library is present in the cinder-volume container
```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ sudo podman exec -it openstack-cinder-volume-podman-0 pip freeze | grep -i infinisdk
infinisdk==206.1.2
```

3.3.	Verify that the backend details are visible in ```/etc/cinder/cinder.conf``` in the cinder-volume container

Given below is an example of iSCSI backend details.

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ sudo podman exec -it openstack-cinder-volume-podman-0 tail -20 /etc/cinder/cinder.conf
...

[infinidat-iscsi1]
driver_use_ssl=True
image_volume_cache_enabled=False
infinidat_iscsi_netspaces=default_iscsi_space
infinidat_pool_name=rhsop_cinder_pool1
infinidat_storage_protocol=iscsi
san_ip=infinibox.domain.com
san_login=your_san_login
san_password=your_san_password
san_thin_provision=True
suppress_requests_ssl_warnings=True
use_multipath_for_image_xfer=True
volume_backend_name=infinidat-iscsi1
volume_driver=cinder.volume.drivers.infinidat.InfiniboxVolumeDriver
backend_host=hostgroup
```
