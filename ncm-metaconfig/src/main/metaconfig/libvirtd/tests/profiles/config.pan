object template config;

include 'metaconfig/libvirtd/config';

prefix "/software/components/metaconfig/services/{/etc/libvirt/libvirtd.conf}/contents";
"network" = dict(
    "listen_tls", false,
    "listen_tcp", true,
    "listen_addr", "localhost",
    "mdns_adv", true,
    "mdns_name", "Virtualization Host Joe Demo",
    "tls_port", 16514,
    "tcp_port", 16509,
);
"socket" = dict(
    "unix_sock_group", "libvirt",
    "unix_sock_ro_perms", "0777",
    "unix_sock_rw_perms", "0770",
    "unix_sock_dir", "/var/run/libvirt",
);
"authn" = dict(
    "auth_tcp", "sasl",
    "auth_tls", "none",
    "auth_unix_ro", "none",
    "auth_unix_rw", "none",
    "access_drivers", list('polkit'),
);
"tls" = dict(
    "key_file", "/etc/pki/libvirt/private/serverkey.pem",
    "cert_file", "/etc/pki/libvirt/servercert.pem",
    "ca_file", "/etc/pki/CA/cacert.pem",
    "crl_file", "/etc/pki/CA/crl.pem",
);
"authz" = dict(
    "sasl_allowed_username_list", list('libvirt/*.domain.org', 'libvirt/*.domain2.org'),
    "tls_no_sanity_certificate", true,
    "tls_no_verify_certificate", true,
    "tls_allowed_dn_list", list("DN1", "DN2"),
);
"processing" = dict(
    "max_clients", 5000,
    "max_queued_clients", 1000,
    "max_anonymous_clients", 20,
    "min_workers", 5,
    "max_workers", 20,
    "prio_workers", 5,
    "max_requests", 20,
    "max_client_requests", 5,
);
"logging" = dict(
    "log_level", 3,
    "log_filters", "3:remote 4:event",
    "log_outputs", "3:syslog:libvirtd",
);
"audit" = dict(
    "audit_level", 2,
    "audit_logging", true,
);
"host_uuid" = "3c3c62d3-acc3-48a1-89bc-67a4cba40516";
"keepalive" = dict(
    "keepalive_interval", 5,
    "keepalive_count", 5,
    "keepalive_required", true,
);
