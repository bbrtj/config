package PCRD::Module::Any::Hooker;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Hooker';

sub init_hook
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	my $initialized = exists $vars->{running};
	$vars->{running} = $enabled;
	return if $initialized;

	my %conf = %{$feature->config // {}};
	foreach my $module (keys %conf) {
		next unless $module eq ucfirst $module;

		foreach my $target_feature (keys %{$conf{$module}}) {
			my @command_args = split /,/, $conf{$module}{$target_feature};
			$self->owner->module($module)->feature($target_feature)->add_execute_hook(
				sub {
					my ($action, $value, $result) = @_;
					return unless $vars->{running};
					return unless $action eq 'w';

					my $cmd_text = 'Hooking command: "' . join(' ', @command_args) . '"';
					$self->owner->broadcast(@command_args)
						->on_done(
							sub {
								say "$cmd_text - success!";
							}
						)->on_fail(
							sub {
								my $ex = shift;
								say "$cmd_text - ERROR: $ex";
							}
						);
				}
			);
		}
	}
}

sub _build_features
{
	return {
		hook => {
			desc => 'Hook into any feature (when setting the value)',
			info => 'Use Hooker.hook.Module.feature=command to hook into a feature',
			mode => 'i',
			needs_agent => 1,
		},
	};
}
1;

