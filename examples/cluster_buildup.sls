# We need to install ceph and its configuration library

packages:
  pkg:
    - installed
    - names:
      - ceph
      - python-ceph-cfg

# We need a ceph configuration file before we start.
#
# Note:
# - The file name is dependennt on the cluster name:
#    /etc/ceph/${CLUSTER_NAME}.conf

/etc/ceph/ceph.conf:
  file:
    - managed
    - source:
        # Where to get the source file will have to be customised to your enviroment.
        - salt://osceph/ceph.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - require:
      - pkg: packages


# First we need to create the keys.
#
# Note:
# - Normally do this manually with "salt '*' ceph.keyring_create type=<keyring_type>"
#   before saving the keys, and use the 'secrets' values below.
# - This only needs to be done once per cluster.


keyring_admin_create:
  module.run:
    - name: ceph.keyring_create
    - kwargs: {
        'keyring_type' : 'admin'
        }
    - require:
      - file: /etc/ceph/ceph.conf


keyring_mon_create:
  module.run:
    - name: ceph.keyring_create
    - kwargs: {
        'keyring_type' : 'mon'
        }
    - require:
      - file: /etc/ceph/ceph.conf


keyring_osd_create:
  module.run:
    - name: ceph.keyring_create
    - kwargs: {
        'keyring_type' : 'osd'
        }
    - require:
      - file: /etc/ceph/ceph.conf


keyring_rgw_create:
  module.run:
    - name: ceph.keyring_create
    - kwargs: {
        'keyring_type' : 'rgw'
        }
    - require:
      - file: /etc/ceph/ceph.conf


keyring_mds_create:
  module.run:
    - name: ceph.keyring_create
    - kwargs: {
        'keyring_type' : 'mds'
        }
    - require:
      - file: /etc/ceph/ceph.conf


# Save the keys to the nodes so ceph can use them.
#
# Note:
# - You should customise the 'secret' values for your site using the values from
#   the previous create step
# - All keys must be saved before the mon is created as this has a side effect
#   of creating keys not managed by salt.


keyring_admin_save:
  module.run:
    - name: ceph.keyring_save
    - kwargs: {
        'keyring_type' : 'admin',
        'secret' : 'AQBR8KhWgKw6FhAAoXvTT6MdBE+bV+zPKzIo6w=='
        }
    - require:
      - module: keyring_admin_create
      - file: /etc/ceph/ceph.conf


keyring_mon_save:
  module.run:
    - name: ceph.keyring_save
    - kwargs: {
        'keyring_type' : 'mon',
        'secret' : 'AQB/8KhWmIfENBAABq8EEbzCJMjEFoazMNb+oQ=='
        }
    - require:
      - module: keyring_mon_create
      - file: /etc/ceph/ceph.conf


keyring_osd_save:
  module.run:
    - name: ceph.keyring_save
    - kwargs: {
        'keyring_type' : 'osd',
        'secret' : 'AQCxU6dWKJzuEBAAjh0WSiThjl+Ruvj3QCsDDQ=='
        }
    - require:
      - module: keyring_osd_create
      - file: /etc/ceph/ceph.conf


keyring_rgw_save:
  module.run:
    - name: ceph.keyring_save
    - kwargs: {
        'keyring_type' : 'rgw',
        'secret' : 'AQDant1WGP7qJBAA1Iqr9YoNo4YExai4ieXYMg=='
        }
    - require:
      - module: keyring_osd_create
      - file: /etc/ceph/ceph.conf


keyring_mds_save:
  module.run:
    - name: ceph.keyring_save
    - kwargs: {
        'keyring_type' : 'mds',
        'secret' : 'AQADn91WzLT9OBAA+LqKkXFBzwszBX4QkCkFYw=='
        }
    - require:
      - module: keyring_osd_create
      - file: /etc/ceph/ceph.conf


# Create the mon server
#
# Note:
# - This will throw and exception on non-mon nodes.
# - This is depenent on having 'saved' the mon and admin keys.
# - Not saving the mds key on all mon nodes has a side effect
#   of creating keys not managed by salt.

mon_create:
    module.run:
    - name: ceph.mon_create
    - require:
      - module: keyring_admin_save
      - module: keyring_mon_save

# Check system is quorum

cluster_status:
    ceph.quorum:
    - require:
      - module: keyring_admin_save
      - module: keyring_mon_save


# Add the OSD key to the clusters authorized key list

keyring_osd_auth_add:
  module.run:
    - name: ceph.keyring_osd_auth_add
    - require:
      - ceph: cluster_status
      - module: keyring_osd_save

# Add the rgw key to the clusters authorized key list

keyring_auth_add_rgw:
  module.run:
    - name: ceph.keyring_rgw_auth_add
    - require:
      - ceph: cluster_status
      - module: keyring_rgw_save

# Add the mds key to the clusters authorized key list

keyring_auth_add_mds:
  module.run:
    - name: ceph.keyring_mds_auth_add
    - require:
      - ceph: cluster_status
      - module: keyring_mds_save

# Prepare disks for OSD use

prepare_vdb:
  module.run:
    - name: ceph.osd_prepare
    - kwargs: {
        osd_dev: /dev/vdb
        }
    - require:
      - module: keyring_osd_auth_add

prepare_vdc:
  module.run:
    - name: ceph.osd_prepare
    - kwargs: {
        osd_dev: /dev/vdc
        }
    - require:
      - module: keyring_osd_auth_add
# Activate OSD's on prepared disks

activate_vdb:
  module.run:
    - name: ceph.osd_activate
    - kwargs: {
        osd_dev: /dev/vdb
        }


activate_vdc:
  module.run:
    - name: ceph.osd_activate
    - kwargs: {
        osd_dev: /dev/vdc
        }

# Prepare for the rgw

rgw_prep:
  module.run:
    - name: ceph.rgw_pools_create
    - require:
      - module: keyring_osd_auth_add

# Create the rgw

rgw_create:
  module.run:
    - name: ceph.rgw_create
    - kwargs: {
        name: rgw.{{ grains['machine_id'] }}
        }
    - require:
      - module: rgw_prep

# Create the mds

mds_create:
  module.run:
    - name: ceph.mds_create
    - kwargs: {
        name: mds.{{ grains['machine_id'] }},
        port: 1000,
        addr:{{ grains['fqdn_ip4'] }}
        }
    - require:
      - module: keyring_osd_auth_add
