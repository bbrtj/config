package PCRD::Module::Any::Acpi;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Acpi';

sub set_signal
{
	my ($self, $feature, $value) = @_;
	my @args = split /\s+/, $value;

	if ($args[0] eq 'button/lid') {
		$feature->dependencies->{'Control.auto_suspend'}->execute('w', 'execute');
		return 'auto suspend';
	}

	return 'doing nothing';
}

sub _build_features
{
	return {
		signal => {
			desc => 'react to acpi signal',
			mode => 'w',
			dependencies => [
				'Control.auto_suspend',
			],
		},
	};
}

1;

