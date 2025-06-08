package PCRD::Module::Any::Acpi;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Acpi';

sub _execute
{
	my ($self, $feature, $depname, @args) = @_;
	my $dep = $feature->dependencies->{$depname};

	if ($dep->functional) {
		$dep->execute(@args);
		return $depname;
	}

	return "$depname (not functional)"
}
sub set_signal
{
	my ($self, $feature, $value) = @_;
	my @args = split /\s+/, $value;
	my ($type, $subtype) = split /\//, shift @args;

	if ($type eq 'button') {
		if ($subtype eq 'lid') {
			return $self->_execute($feature, 'Control.auto_suspend', 'w', 'execute');
		}
		elsif ($subtype eq 'volumeup') {
			return $self->_execute($feature, 'Sound.volume', 'w', '+1');
		}
		elsif ($subtype eq 'volumedown') {
			return $self->_execute($feature, 'Sound.volume', 'w', '-1');
		}
		elsif ($subtype eq 'mute') {
			return $self->_execute($feature, 'Sound.mute', 'w', 'toggle');
		}
	}
	elsif ($type eq 'video') {
		if ($subtype eq 'brightnessup') {
			return $self->_execute($feature, 'Display.brightness', 'w', '+1');
		}
		elsif ($subtype eq 'brightnessdown') {
			return $self->_execute($feature, 'Display.brightness', 'w', '-1');
		}
	}
	elsif ($type eq 'ac_adapter') {
		return $self->_execute($feature, 'Status.build_default_line', 'w', 'ac');
	}

	return 'unimplemented';
}

sub _build_features
{
	return {
		signal => {
			desc => 'react to acpi signal',
			mode => 'w',
			dependencies => [
				'Control.auto_suspend',
				'Status.build_default_line',
				'Sound.volume',
				'Sound.mute',
				'Display.brightness',
			],
		},
	};
}

1;

