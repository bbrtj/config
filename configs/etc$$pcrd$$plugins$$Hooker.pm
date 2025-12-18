package PCRD::Module::Any::Hooker;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Hooker';

sub _make_action
{
	my ($self, $feature, $conf_hash) = @_;

	my ($type) = grep { exists $conf_hash->{$_} } qw(command feature notification info);
	die 'no valid hook type specified'
		unless defined $type;

	my @args = split /,/, $conf_hash->{$type};

	if ($type eq 'command') {
		return sub {
			$self->owner->broadcast(@args);
		};
	}
	elsif ($type eq 'feature') {
		my ($module, $feature, $value) = @args;
		return sub {
			$self->owner->module($module)->feature($feature)
				->execute($value ? ('w', $value) : ('r'));
		};
	}
	elsif ($type eq 'notification') {
		my $title = shift @args;
		return sub {
			# TODO: non-pcrd notification
			$self->owner->broadcast(@args)->on_done(
				sub {
					my $content = join '', @_;
					$feature->dependencies->{'Dunst.info'}->execute('w', "$title,$content");
				}
			);
		};
	}
	elsif ($type eq 'info') {
		my $title = shift @args;
		return sub {
			$self->owner->broadcast(@args)->on_done(
				sub {
					my $content = join '', @_;
					$feature->dependencies->{'Dunst.info'}->execute('w', "$title,$content");
				}
			);
		};
	}
}

sub init_hook
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	my $initialized = exists $vars->{running};
	$vars->{running} = $enabled;
	return if $initialized;

	foreach my $module (keys %{$vars->{hooks}}) {
		foreach my $target_feature (keys %{$vars->{hooks}{$module}}) {
			my $code = $vars->{hooks}{$module}{$target_feature};

			$self->owner->module($module)->feature($target_feature)->add_execute_hook(
				sub {
					my ($action, $value, $result) = @_;
					return unless $vars->{running};
					return unless $action eq 'w';

					$code->()
						->on_fail(
							sub {
								my $ex = shift;
								say "Hooking command error: $ex";
							}
						);
				}
			);
		}
	}
}

sub prepare_hook
{
	my ($self, $feature) = @_;
	my $vars = $feature->vars;
	my %conf = %{$feature->config // {}};

	foreach my $module (keys %conf) {
		next unless $module eq ucfirst $module;

		foreach my $target_feature (keys %{$conf{$module}}) {
			$vars->{hooks}{$module}{$target_feature} = $self->_make_action($feature, $conf{$module}{$target_feature});
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

