# ${license-info}
# ${developer-info}
# ${author-info}

#
# Example NCM Component with NVA API config access
#
###############################################################################

package NCM::Component::iscsitarget;
#
# a few standard statements, mandatory for all components
#

use strict;
use NCM::Component;
use vars qw(@ISA $EC);
@ISA = qw(NCM::Component);
$EC=LC::Exception::Context->new->will_store_all;


use EDG::WP4::CCM::Element;
use CAF::FileWriter;
use CAF::Process;
use LC::File;

use Sys::Hostname;

#
# catch all exceptions. This seems to be the way to deal with them
# in NCM components..
#
$EC->error_handler(\&my_handler);
sub my_handler {
	my($ec, $e) = @_;
	$e->has_been_reported(1);
}


# search function: dumps the config tree recursively
# code adapted from Rafael A. Leiva
#
#my $depth;
#sub search {
#    my ($self,$element) = @_;
#    my $i;
#    my $str='';
#    for( $i=0 ; $i<$depth ; $i++ ) {
#      $str .= "  ";
#    }
#    if( $element->isProperty() ) {
#      $str .='$ '.$element->getName() . " : ";
#      $str .="string (" if $element->isType(EDG::WP4::CCM::Element::STRING);
#      $str .="long ("   if $element->isType(EDG::WP4::CCM::Element::LONG);
#      $str .="double (" if $element->isType(EDG::WP4::CCM::Element::DOUBLE);
#      $str .="boolean ("if $element->isType(EDG::WP4::CCM::Element::BOOLEAN);
#      $str .= $element->getValue() . ")";
#      $self->report($str);
#      $depth--;
#      return;
#    }
#    $self->report( $str."+-" . $element->getName());
#    while( $element->hasNextElement() ) {
#      $depth++;
#      $self->search($element->getNextElement(),$depth);
#    }
#    $depth--;
#    return;
#}


# translate a CDB path to a real /dev/* path
# $1: cdb_path relative to /system/blockdevices
sub cdbpath_to_realpath {
	my ($self,$config,$cdbp)=@_;

	my @a=split('/',$cdbp);
	my $devname="UNKNOWN";
	# base path for ncm-blockdevices, or describing blockdevices in general
	my $bd_base="/system/blockdevices";

	$self->debug(2,"cdbpath_to_realpath: @a");

	# FIXME handle errors in $cdbp format
	   if ($a[0] eq "physical_devs") { $devname="/dev/$a[1]"; }
	elsif ($a[0] eq "partitions") { $devname="/dev/$a[1]"; }
	elsif ($a[0] eq "md") { $devname="/dev/$a[1]"; }
	elsif ($a[0] eq "hwraid") { $devname="HWRAID:use_physical_devs"; } # FIXME
	elsif ($a[0] eq "logical_volumes") { 
		if ($config->elementExists("$bd_base/$a[0]/$a[1]/volume_group")) {
			my $vg=$config->getElement("$bd_base/$a[0]/$a[1]/volume_group")->getValue();
			$devname="/dev/mapper/$vg-$a[1]"; 
		} else {
			$self->error("LVM volume $bd_base/$a[0]/$a[1]/volume_group not found in CDB!");
		}
	}
	elsif ($a[0] eq "files") { $devname="FILES:not_with_stgt";  }  # FIXME
	else { $self->error("Unsupported device_path '$cdbp'!"); }

	return $devname;
}

##################################################################
# walk config tree and generate config files
# for both tgtd and IET targets
##################################################################
sub genconffiles {
    my ($self,$config) = @_;
    my $tgtdconfig="### NCM-autogenerated ###\n";
    my $tgtdconfig_path="/etc/tgt/targets.conf";
	my $host=hostname; 
	$host =~ s/\..*//;

    #my $ietconfig="### NCM-autogenerated ###\n";
    #my $ietconfig_path="/etc/x";

	my $basepath="/software/components/iscsitarget/targets";

	my $path="";
	my $name;
	my $val;

	my $cdb_device_path=""; # /hardware/blockdevices/blah
	my $targetdevice=""; # /dev/sdX
	my $targetname=""; # symbolic name for config file
	my @initiators=(); 
	my $auth_type="";
	my $auth_resource="";

	# -------------

	# ugly but works
	# loop by number, otherwise, if one of these is missing
	# (e.g. deleted by some user or a crappy tool)
	# getNextElement will stop processing at the 'hole'

	my $ii;
	for ($ii=0; $ii<1000; $ii++ ) { 

		$cdb_device_path=""; # pan string relative to /hardware/blockdevices
		$targetname=""; # symbolic name for config file
		@initiators=();
		$auth_type="";
		$auth_resource="";

		$path="$basepath/$ii";
		
		if ($config->elementExists($path)) {
			my $re=$config->getElement($path);

			while ($re->hasNextElement()) {
				my $ce=$re->getNextElement();
				$val=$ce->getValue();
				$name=$ce->getName();

				   if($name eq "device_path") {$cdb_device_path=$val; }
				elsif($name eq "authentication_type") {$auth_type=$val; }
				elsif($name eq "authentication_resource") {$auth_resource=$val; }
				elsif($name eq "initiators") {
					# FIXME there's probably a better way to do this.
					# here we walk the 'initiators' array
					my $ie=$config->getElement($path."/$name");
					while ($ie->hasNextElement()) {
						my $ini=$ie->getNextElement();
						$name=$ini->getName();
						$val=$ini->getValue();
						$self->debug(1,"INITIATOR $path/$name : $val");
						push(@initiators,$val);
					};
				}; # initiators
			}; # this actual target
		}; # this list element (containing 0..1 targets)
		
		if ($cdb_device_path ne "") {
			$self->debug(1,"Found: cdb_device_path:$cdb_device_path, auth: $auth_type/$auth_resource");
			$targetdevice=$self->cdbpath_to_realpath($config,$cdb_device_path);
			$targetname=$cdb_device_path;
			$targetname =~ s/\//./;
			$tgtdconfig.="<target $host.$targetname>\n";
			$tgtdconfig.="	backing-store $targetdevice\n";
			foreach my $i (@initiators) {
				$self->debug(1,"	...initiator: $i ");
				$tgtdconfig.="	initiator-address $i\n"; 
			}
			$tgtdconfig.="</target>\n";
		}; # found target
	};

	my $oldtgtdconfig=LC::File::file_contents($tgtdconfig_path);

	my $need=0;

	if (not defined $oldtgtdconfig) { $need=1; $self->info("Config file $tgtdconfig_path did not exist"); }
	elsif ( $oldtgtdconfig ne $tgtdconfig ) { $need=1; $self->info("Config file $tgtdconfig_path updated"); }

	if ($need==1) {
		my $fh=CAF::FileWriter->open($tgtdconfig_path, log => $self);
#		$self->report("--------OLD STUFF:---------\n".$oldtgtdconfig);
#		$self->report("--------NEW STUFF:---------\n".$tgtdconfig);
		print $fh $tgtdconfig;
		$fh->close();

		# 'restart' does not quite work.. BUG in tgtd
		my $proc = CAF::Process->new (["/etc/init.d/tgtd", "stop"]);
		$proc->run(); # not interested in the results
		sleep(3);
		my $proc = CAF::Process->new (["/etc/init.d/tgtd", "start"]);
		$proc->run(); # not interested in the results
	}


    return;
}

##########################################################################
sub Configure($$) {
##########################################################################
  my ($self,$config)=@_;

  #$self->info("hello node");

  if ($NoAction) {
    $self->info("I am running in fake mode (noaction)");
  }

  #my $element = $config->getElement('/software/components/iscsitarget');
  #$depth=0;
  #$self->search($element);

  $self->genconffiles($config);

  # the scsi-target-utils rpm does not switch it on by default
  $self->info("Making sure that tgtd will run at next reboot...");
  my $proc = CAF::Process->new (["/sbin/chkconfig", "tgtd","on"]);
  $proc->run(); # not interested in the results

  $self->OK("Everything is fine...");

  return; # return code is not checked.

}

1; # Perl module requirement.

