========================================
INFINIDAT InfiniBox Block Storage driver
========================================

The INFINIDAT Block Storage volume driver provides iSCSI and Fibre Channel
support for INFINIDAT InfiniBox storage systems.

This section explains how to configure the INFINIDAT driver.

Supported operations
~~~~~~~~~~~~~~~~~~~~

* Create, delete, attach, and detach volumes.
* Create, list, and delete volume snapshots.
* Create a volume from a snapshot.
* Copy a volume to an image.
* Copy an image to a volume.
* Clone a volume.
* Extend a volume.
* Get volume statistics.
* Create, modify, delete, and list consistency groups.
* Create, modify, delete, and list snapshots of consistency groups.
* Create consistency group from consistency group or consistency group
  snapshot.
* Revert a volume to a snapshot.
* Manage and unmanage volumes and snapshots.
* List manageable volumes and snapshots.
* Attach a volume to multiple instances at once (multi-attach).
* Host and storage assisted volume migration.
* Efficient non-disruptive volume backup.
* Replicate volumes and consistency groups to remote Infinidat storage(s).
* Enable and disable replication for a volume group.
* List or replication targets for a volume group.
* Failover host to replicated backends.

External package installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The driver requires the ``infinisdk`` package for communicating with
InfiniBox systems. Install the package from PyPI using the following command:

.. code-block:: console

   $ pip3 install infinisdk

Setting up the storage array
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create a storage pool object on the InfiniBox array in advance.
The storage pool will contain volumes managed by OpenStack.
Mixing OpenStack APIs and non-OpenStack methods are not supported
when used to attach the same hosts via the same protocol.
For example, it is not possible to create boot-from-SAN volumes
and OpenStack volumes for the same host with Fibre Channel.
Instead, use a different protocol for one of the volumes.
Refer to the InfiniBox manuals for details on pool management.

Driver configuration
~~~~~~~~~~~~~~~~~~~~

Edit the ``cinder.conf`` file, which is usually located under the following
path ``/etc/cinder/cinder.conf``.

* Add a section for the INFINIDAT driver back end.

* Under the ``[DEFAULT]`` section, set the ``enabled_backends`` parameter with
  the name of the new back-end section.

Configure the driver back-end section with the parameters below.

* Configure the driver name by setting the following parameter:

  .. code-block:: ini

     volume_driver = cinder.volume.drivers.infinidat.InfiniboxVolumeDriver

* Configure the management IP of the InfiniBox array by adding the following
  parameter:

  .. code-block:: ini

     san_ip = InfiniBox management IP

* Verify that the InfiniBox array can be managed via an HTTPS connection.
  And the ``driver_use_ssl`` parameter should be set to ``true`` to enable
  use of the HTTPS protocol. HTTP can also be used if ``driver_use_ssl``
  is set to (or defaults to) ``false``. To suppress requests library SSL
  certificate warnings, set the ``suppress_requests_ssl_warnings`` parameter
  to ``true``.

  .. code-block:: ini

     driver_use_ssl = true/false
     suppress_requests_ssl_warnings = true/false

  These parameters defaults to ``false``.

* Configure user credentials.

  The driver requires an InfiniBox user with administrative privileges.
  We recommend creating a dedicated OpenStack user account
  that holds a pool admin user role.
  Refer to the InfiniBox manuals for details on user account management.
  Configure the user credentials by adding the following parameters:

  .. code-block:: ini

     san_login = infinibox_username
     san_password = infinibox_password

* Configure the name of the InfiniBox pool by adding the following parameter:

  .. code-block:: ini

     infinidat_pool_name = Pool defined in InfiniBox

* The back-end name is an identifier for the back end.
  We recommend using the same name as the name of the section.
  Configure the back-end name by adding the following parameter:

  .. code-block:: ini

     volume_backend_name = back-end name

* Thin provisioning.

  The INFINIDAT driver supports creating thin or thick provisioned volumes.
  Configure thin or thick provisioning by adding the following parameter:

  .. code-block:: ini

     san_thin_provision = true/false

  This parameter defaults to ``true``.

* Configure the connectivity protocol.

  The InfiniBox driver supports connection to the InfiniBox system in both
  the fibre channel and iSCSI protocols.
  Configure the desired protocol by adding the following parameter:

  .. code-block:: ini

     infinidat_storage_protocol = iscsi/fc

  This parameter defaults to ``fc``.

* Configure iSCSI netspaces.

  When using the iSCSI protocol to connect to InfiniBox systems, you must
  configure one or more iSCSI network spaces in the InfiniBox storage array.
  Refer to the InfiniBox manuals for details on network space management.
  Configure the names of the iSCSI network spaces to connect to by adding
  the following parameter:

  .. code-block:: ini

     infinidat_iscsi_netspaces = iscsi_netspace

  Multiple network spaces can be specified by a comma separated string.

  This parameter is ignored when using the FC protocol.

* Configure CHAP

  InfiniBox supports CHAP authentication when using the iSCSI protocol. To
  enable CHAP authentication, add the following parameter:

  .. code-block:: ini

     use_chap_auth = true

  To manually define the username and password, add the following parameters:

  .. code-block:: ini

     chap_username = username
     chap_password = password

  If the CHAP username or password are not defined, they will be
  auto-generated by the driver.

  The CHAP parameters are ignored when using the FC protocol.

* Volume compression

  Volume compression is available for all supported InfiniBox versions.
  By default, compression for all newly created volumes is inherited from
  its parent pool at creation time. All pools are created by default with
  compression enabled.

  To explicitly enable or disable compression for all newly created volumes,
  add the following configuration parameter:

  .. code-block:: ini

     infinidat_use_compression = true/false

  Or leave this configuration parameter unset (commented out) for all
  created volumes to inherit their compression setting from their parent
  pool at creation time. The default value is unset.

* Replication

  Add the ``replication_device`` configuration option to the storage
  backend configuration to specify another InfiniBox storage host to
  replicate volumes and consistency groups to:

  .. code-block:: ini

     replication_device = backend_id:infinidat-pool-b,
                          san_ip:10.4.5.6,
                          pool_name:pool-b,
                          replication_type:active_active,
                          uniform_access:true,
                          alua_optimized:true

     replication_device = backend_id:infinidat-pool-c,
                          san_ip:10.7.8.9,
                          pool_name:pool-c,
                          replication_type:active_active,
                          uniform_access:true,
                          alua_optimized:false

  Where ``backend_id`` is the unique identifier of the remote InfiniBox
  storage host, ``san_ip`` is the management IP address of the remote
  InfiniBox storage host, ``san_login`` and ``san_password`` are the
  credentials to access the remote InfiniBox storage host. ``pool_name``
  is the storage pool will contain replicated volumes and groups.
  The ``uniform_access`` option enables a uniform topology, and the
  OpenStack hosts are connected to both InfiniBox storage hosts, and the
  volumes are mapped to the OpenStack hosts on both InfiniBox storage hosts.
  In this topology, the OpenStack host can perform I/Os on both InfiniBox
  storage hosts simultaneously. The ``alua_optimized`` option controls SCSI
  Asymmetric Logical Unit Access (ALUA).

  .. list-table:: Available replication configuration options
     :header-rows: 1

     * - Option
       - Type
       - Default
       - Description
     * - ``backend_id``
       - ``String``
       - ``None``
       - Unique identifier of the remote InfiniBox storage host
     * - ``san_ip``
       - ``String``
       - ``None``
       - Management IP address or FQDN for the remote Infinidat storage host
     * - ``san_login``
       - ``String``
       - Inherited from local storage backend
       - Username to access the remote Infinidat storage host
     * - ``san_password``
       - ``String``
       - Inherited from local storage backend
       - The user password to access the remote Infinidat storage host
     * - ``use_ssl``
       - ``Boolean``
       - Inherited from local storage backend
       - Use SSL/TLS for API on the remote Infinidat storage host
     * - ``pool_name``
       - ``String``
       - Inherited from local storage backend
       - A storage pool name in the remote Infinidat storage host
     * - ``replication_type``
       - ``String``
       - ``active_active``
       - Replication type, currently only ``active_active`` replication is supported
     * - ``uniform_access``
       - ``Boolean``
       - ``True``
       - Enables uniform access for all replicated volumes
     * - ``alua_optimized``
       - ``Boolean``
       - ``True``
       - Enables ALUA optimized paths for all replicated volumes

  A volume is only replicated if the volume is of a volume-type that
  contains the extra specs ``replication_enabled`` set to ``<is> True``
  and ``infinidat:replication_backend`` set to the valid replication
  backend id.

  To create a volume type that enables replication to remote InfiniBox
  storage host:

  .. code-block:: console

     $ openstack volume type create replicated-volume-type

     $ openstack volume type set \
         --property replication_enabled='<is> True' \
         replicated-volume-type

     $ openstack volume type set \
         --property infinidat:replication_backend='infinidat-pool-b' \
         replicated-volume-type

  A volume group is only replicated if the group is of a group-type that
  contains the extra specs ``group_replication_enabled`` set to ``<is> True``
  and ``infinidat:replication_backend`` set to the valid replication
  backend id.

  To create a group type that enables replication to remote InfiniBox
  storage host:

  .. code-block:: console

     $ openstack volume group type create replicated-group-type

     $ openstack volume group type set \
         --property consistent_group_snapshot_enabled='<is> True' \
         replicated-group-type

     $ openstack volume group type set \
         --property group_replication_enabled='<is> True' \
         replicated-group-type

     $ openstack volume group type set \
         --property infinidat:replication_backend='infinidat-pool-b' \
         replicated-group-type

* Volume types

  Create a new volume type for each distinct ``volume_backend_name`` value
  that you added in the ``cinder.conf`` file. The example below assumes that
  the same ``volume_backend_name=infinidat-pool-a`` option was specified in
  all of the entries, and specifies that the volume type ``infinidat`` can be
  used to allocate volumes from any of them. Example of creating a volume type:

    .. code-block:: console

       $ openstack volume type create infinidat

       $ openstack volume type set --property volume_backend_name=infinidat-pool-a infinidat

After modifying the ``cinder.conf`` file, restart the ``cinder-volume``
service.

Configuration example
~~~~~~~~~~~~~~~~~~~~~

.. code-block:: ini

   [DEFAULT]
   enabled_backends = infinidat-pool-a

   [infinidat-pool-a]
   volume_driver = cinder.volume.drivers.infinidat.InfiniboxVolumeDriver
   volume_backend_name = infinidat-pool-a
   driver_use_ssl = true
   suppress_requests_ssl_warnings = true
   san_ip = 10.1.2.3
   san_login = openstackuser
   san_password = openstackpass
   san_thin_provision = true
   infinidat_pool_name = pool-a
   infinidat_storage_protocol = iscsi
   infinidat_iscsi_netspaces = default_iscsi_space
   replication_device = backend_id:infinidat-pool-b,
                        san_ip:10.4.5.6,
                        pool_name:pool-b,
                        replication_type:active_active,
                        uniform_access:true,
                        alua_optimized:true

Driver-specific options
~~~~~~~~~~~~~~~~~~~~~~~

The following table contains the configuration options that are specific
to the INFINIDAT driver.

.. config-table::
   :config-target: INFINIDAT InfiniBox

   cinder.volume.drivers.infinidat
