# ${license-info}
# ${developer-info}
# ${author-info}

 
unique template components/sysconfig/config-rpm;
include { 'components/sysconfig/schema' };
 
# Package to install
"/software/packages" = pkg_repl("ncm-${project.artifactId}", "${no-snapshot-version}-${RELEASE}", "noarch");

'/software/components/sysconfig/dependencies/pre' ?= list('spma');

'/software/components/sysconfig/version' ?= '${project.version}';
