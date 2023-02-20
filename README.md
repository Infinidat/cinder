# Documentation

 - [RedHat OpenStack Platform 16.2 Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/director_installation_and_usage/index)
 - [RedHat OpenStack Platform 16.2 Overcloud Parameters](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/overcloud_parameters/index)
 - [RedHat OpenStack Platform 16.2 Multipath Configuration](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html/storage_guide/assembly-configuring-the-block-storage-service_osp-storage-guide#con-multipath-configuration_configuring-cinder)
 - [Openstack Cinder Configuration For Infinidat Driver](https://docs.openstack.org/cinder/train/configuration/block-storage/drivers/infinidat-volume-driver.html)
 - [Linux Man Page (5) For multipath.conf](https://manpages.org/multipathconf/5)

# Infinidat Infinibox storage deployment Guide for RHOSP 16.2

## Overview

This page provides detailed steps on how to enable the containerized Infinidat cinder driver for RedHat OpenStack Platform.
It also contains steps to deploy & configure Infinidat Infinibox backends for RedHat OpenStack Platform 16.2.

The custom Cinder container image contains following packages:

- infinisdk
- capacity
- infi.dtypes.wwn

## Prerequisites

* Red Hat OpenStack Platform 16.2 with RedHat Enterprise Linux 8.4.

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
        tag: 16.2
        ...
```
Check the [example "containers-prepare-parameter.yaml" file](https://github.com/Infinidat/cinder/blob/doc/rhosp16.2/examples/containers-prepare-parameter.yaml) from our repository.

> Note: It is possible to specify minor version in the tag to deploy specific supported releae. Example: 16.2.5

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
        tag: 16.2.5
        ...
```

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

> Note: Only iSCSI backend is currently officially supported. FC backend has not yet passed the certification for the RedHat OpenStack Platform 16.2

The Infindiat Infinibox environment file for RedHat OpenStack Platform contains the settings for each backend you want to define.

Create the environment file "cinder-infinidat-config.yaml" with below parameters and other backend details.

```
parameter_defaults:
  CinderEnableIscsiBackend: false
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
      infinidat-iscsi1/infinidat_pool_name:
        value: rhsop_cinder_pool1
      infinidat-iscsi1/infinidat_storage_protocol:
        value: iscsi
      infinidat-iscsi1/infinidat_iscsi_netspaces:
        value: default_iscsi_space

      infinidat-fc1/volume_driver:
        value: cinder.volume.drivers.infinidat.InfiniboxVolumeDriver
      infinidat-fc1/volume_backend_name:
        value: infinidat-fc1
      infinidat-fc1/san_ip:
        value: infinibox.domain.com
      infinidat-fc1/san_login:
        value: censored
      infinidat-fc1/san_password:
        value: censored
      infinidat-fc1/infinidat_pool_name:
        value: rhsop_cinder_pool1
      infinidat-fc1/infinidat_storage_protocol:
        value: fc
      infinidat-fc1/san_thin_provision:
        value: true

    cinder_user_enabled_backends:
    - infinidat-iscsi1
    - infinidat-fc1

```

Check the [example "cinder-infinidat-config-iscsi.yaml" file](https://github.com/Infinidat/cinder/blob/doc/rhosp16.2/examples/cinder-infinidat-config-iscsi.yaml) from our repository.

#### Additional Help

For further details of Infinidat Infinibox storage cinder driver configuration, refer to an official OpenStack documentation [Chapter: INFINIDAT InfiniBox Block Storage driver](https://docs.openstack.org/cinder/train/configuration/block-storage/drivers/infinidat-volume-driver.html)

> Note: Infinidat recommends you to use Infinidat specific multipath.conf instead of generic one.

> Note: RedHat OpenStack Platform 16.2 supports configuring only limited set of options for multipath.conf.    
> For further details refer to [RedHat OpenStack Platform 16.2 Storage Guide. Chapter: 2.12.1.1. Multipath heat template parameters](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html/storage_guide/assembly-configuring-the-block-storage-service_osp-storage-guide#ref_multipath-heat-template-parameters_configuring-cinder).    
> Follow the [RedHat OpenStack Platform 16.2 Storage Guide. Chapter: 2.12 Multipath configuration](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html/storage_guide/assembly-configuring-the-block-storage-service_osp-storage-guide#con-multipath-configuration_configuring-cinder) to specify and deploy custom multipath.conf.

> Note: For all the options available in multipath.conf refer to [Linux Man Page (5) For multipath.conf](https://manpages.org/multipathconf/5)

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

3.1.    Source the overcloudrc file
```
[stack@rhosp-director ~]$ source overcloudrc
```

3.2.    Check cinder volume services are up and running
```
(overcloud) [stack@rhosp-director ~]$ openstack volume service list --long
+------------------+----------------------------+------+---------+-------+----------------------------+-----------------+
| Binary           | Host                       | Zone | Status  | State | Updated At                 | Disabled Reason |
+------------------+----------------------------+------+---------+-------+----------------------------+-----------------+
| cinder-scheduler | overcloud-controller-0     | nova | enabled | up    | 2022-12-20T14:45:15.000000 | None            |
| cinder-backup    | overcloud-controller-0     | nova | enabled | up    | 2022-12-20T14:45:17.000000 | None            |
| cinder-volume    | hostgroup@infinidat-iscsi1 | nova | enabled | up    | 2022-12-20T14:45:18.000000 | None            |
| cinder-volume    | hostgroup@infinidat-fc1    | nova | enabled | up    | 2022-12-20T14:45:14.000000 | None            |
+------------------+----------------------------+------+---------+-------+----------------------------+-----------------+
```

3.3.	Create necessary volume types for deployed backends
```
(overcloud) [stack@rhosp-director ~]$ openstack volume type create --public infinidat-iscsi1
(overcloud) [stack@rhosp-director ~]$ openstack volume type create --public infinidat-fc1
(overcloud) [stack@rhosp-director ~]$ openstack volume type set --name infinidat-iscsi1 --description "Multibackend volume type 1" --property volume_backend_name="infinidat-iscsi1" infinidat-iscsi1
(overcloud) [stack@rhosp-director ~]$ openstack volume type set --name infinidat-fc1 --description "Multibackend volume type 2" --property volume_backend_name="infinidat-fc1" infinidat-fc1
```

3.4.	Check cinder volume types are present
```
(overcloud) [stack@rhosp-director ~]$ openstack volume type list --long
+--------------------------------------+------------------+-----------+-----------------------------------------------------------------+----------------------------------------+
| ID                                   | Name             | Is Public | Description                                                     | Properties                             |
+--------------------------------------+------------------+-----------+-----------------------------------------------------------------+----------------------------------------+
| 272a5f3c-780b-468d-94bf-fdcdf618a905 | infinidat-fc1    | True      | Multibackend volume type 2                                      | volume_backend_name='infinidat-fc1'    |
| f116ed45-8a8e-4e43-980a-dfa865618d16 | infinidat-iscsi1 | True      | Multibackend volume type 1                                      | volume_backend_name='infinidat-iscsi1' |
| 53736d5f-3731-420a-9291-0029eba553b3 | __DEFAULT__      | True      | For internal use, 'tripleo'          is the default volume type |                                        |
+--------------------------------------+------------------+-----------+-----------------------------------------------------------------+----------------------------------------+
```

3.5.	Verify the functionality by creating volumes and ensuring available status
```
(overcloud) [stack@rhosp-director ~]$ openstack volume create --size 1 test-iscsi1
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| attachments         | []                                   |
| availability_zone   | nova                                 |
| bootable            | false                                |
| consistencygroup_id | None                                 |
| created_at          | 2022-12-20T14:53:45.652967           |
| description         | None                                 |
| encrypted           | False                                |
| id                  | 70a28828-a929-484b-87e9-6d2648b8dc18 |
| migration_status    | None                                 |
| multiattach         | False                                |
| name                | test-iscsi1                          |
| properties          |                                      |
| replication_status  | None                                 |
| size                | 1                                    |
| snapshot_id         | None                                 |
| source_volid        | None                                 |
| status              | creating                             |
| type                | infinidat-iscsi1                     |
| updated_at          | None                                 |
| user_id             | d1424b1b80284108b4016379019c96f1     |
+---------------------+--------------------------------------+
(overcloud) [stack@rhosp-director ~]$ openstack volume show test-iscsi1
+--------------------------------+--------------------------------------+
| Field                          | Value                                |
+--------------------------------+--------------------------------------+
| attachments                    | []                                   |
| availability_zone              | nova                                 |
| bootable                       | false                                |
| consistencygroup_id            | None                                 |
| created_at                     | 2022-12-20T14:53:45.000000           |
| description                    | None                                 |
| encrypted                      | False                                |
| id                             | 70a28828-a929-484b-87e9-6d2648b8dc18 |
| migration_status               | None                                 |
| multiattach                    | False                                |
| name                           | test-iscsi1                          |
| os-vol-host-attr:host          | None                                 |
| os-vol-mig-status-attr:migstat | None                                 |
| os-vol-mig-status-attr:name_id | None                                 |
| os-vol-tenant-attr:tenant_id   | cd5d04a84f93499daa7b01df850724f0     |
| properties                     |                                      |
| replication_status             | None                                 |
| size                           | 1                                    |
| snapshot_id                    | None                                 |
| source_volid                   | None                                 |
| status                         | available                            |
| type                           | infinidat-iscsi1                     |
| updated_at                     | 2022-12-20T14:53:47.000000           |
| user_id                        | d1424b1b80284108b4016379019c96f1     |
+--------------------------------+--------------------------------------+
(overcloud) [stack@rhosp-director ~]$ openstack volume create --size 1 --type infinidat-fc1 test-fc1
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| attachments         | []                                   |
| availability_zone   | nova                                 |
| bootable            | false                                |
| consistencygroup_id | None                                 |
| created_at          | 2022-12-20T14:54:15.133001           |
| description         | None                                 |
| encrypted           | False                                |
| id                  | cd6e8f2a-14f6-4dfb-a270-34150b9498a4 |
| migration_status    | None                                 |
| multiattach         | False                                |
| name                | test-fc1                             |
| properties          |                                      |
| replication_status  | None                                 |
| size                | 1                                    |
| snapshot_id         | None                                 |
| source_volid        | None                                 |
| status              | creating                             |
| type                | infinidat-fc1                        |
| updated_at          | None                                 |
| user_id             | d1424b1b80284108b4016379019c96f1     |
+---------------------+--------------------------------------+
(overcloud) [stack@rhosp-director ~]$ openstack volume show test-fc1
+--------------------------------+--------------------------------------+
| Field                          | Value                                |
+--------------------------------+--------------------------------------+
| attachments                    | []                                   |
| availability_zone              | nova                                 |
| bootable                       | false                                |
| consistencygroup_id            | None                                 |
| created_at                     | 2022-12-20T14:54:15.000000           |
| description                    | None                                 |
| encrypted                      | False                                |
| id                             | cd6e8f2a-14f6-4dfb-a270-34150b9498a4 |
| migration_status               | None                                 |
| multiattach                    | False                                |
| name                           | test-fc1                             |
| os-vol-host-attr:host          | None                                 |
| os-vol-mig-status-attr:migstat | None                                 |
| os-vol-mig-status-attr:name_id | None                                 |
| os-vol-tenant-attr:tenant_id   | cd5d04a84f93499daa7b01df850724f0     |
| properties                     |                                      |
| replication_status             | None                                 |
| size                           | 1                                    |
| snapshot_id                    | None                                 |
| source_volid                   | None                                 |
| status                         | available                            |
| type                           | infinidat-fc1                        |
| updated_at                     | 2022-12-20T14:54:17.000000           |
| user_id                        | d1424b1b80284108b4016379019c96f1     |
+--------------------------------+--------------------------------------+
```
