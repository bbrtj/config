package PCRD::Module::Any::Control;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Control';

use constant DUNST_APP => 'pcrd';
use constant DUNST_ID => 92137;

sub _dunstify
{
	my ($self, $title, $content, %args) = @_;

	PCRD::Util::slurp_command(
		'dunstify',
		$title, $content,
		%args
	);
}

sub _dunstify_pcrd
{
	my ($self, $title, $content, $error) = @_;

	$self->_dunstify(
		$title, $content,
		'-a', DUNST_APP,
		'-r', DUNST_ID,
		'-u', $error ? 'critical' : 'low'
	);
}

sub _dunstify_pcrd_conf
{
	my ($self, $conf, $error) = @_;
	return unless defined $conf && length $conf;

	my ($title, $content) = split /,/, $conf;
	return $self->_dunstify_pcrd($title, $content, $error);
}

sub check_power
{
	my ($self, $feature) = @_;

	return $self->check_dependency('Power.capacity')
		// $self->check_dependency('Power.charging')
		// undef;
}

sub init_power
{
	my ($self, $feature) = @_;

	$feature->vars->{last_battery} = 100;
	$feature->vars->{notified} = 0;
	$feature->vars->{last_charging} = 0;
	$self->owner->module('Power')->feature('capacity')->add_execute_hook(
		sub {
			my ($action, $value, $result) = @_;
			my $vars = $feature->vars;
			my $config = $feature->config;

			my $old = $vars->{last_battery};
			if ($result != $old) {
				$vars->{last_battery} = $result;

				if (!$vars->{notified} && $result <= $config->{capacity}) {
					$self->_dunstify('Low power', "Battery at $result%", '-u', 'critical');
					$vars->{notified} = 1;
				}
				elsif ($result > $config->{capacity}) {
					$vars->{notified} = 0;
				}
			}
		}
	);

	$self->owner->module('Power')->feature('charging')->add_execute_hook(
		sub {
			my ($action, $value, $result) = @_;
			my $vars = $feature->vars;

			my $old = $vars->{last_charging};
			if ($result != $old) {
				$vars->{last_charging} = $result;

				my $text = $result ? 'charging' : 'discharging';
				$self->_dunstify(ucfirst $text, "Device is now $text", '-u', 'low');
			}
		}
	);
}

sub init_startup
{
	my ($self, $feature) = @_;

	$self->_dunstify_pcrd_conf($feature->{config}{notification});
}

sub prepare_gestures
{
	my ($self, $feature) = @_;

	my $actions = $feature->config->{action} // {};
	foreach my $action (keys %{$actions}) {
		my ($type, @args) = split /,/, $actions->{$action};
		my $code;

		if ($type eq 'command') {
			$code = sub {
				PCRD::Util::slurp_command(@args);
			};
		}
		elsif ($type eq 'feature') {
			my ($module, $feature, $value) = @args;
			$code = sub {
				$self->owner->module($module)->feature($feature)
					->execute($value ? ('w', $value) : ());
			};
		}
		elsif ($type eq 'notification') {
			my $title = shift @args;
			$code = sub {
				my @content = PCRD::Util::slurp_command(@args);
				$self->_dunstify($title, join '', @content);
			};
		}
		elsif ($type eq 'info') {
			my $title = shift @args;
			$code = sub {
				my @content = PCRD::Util::slurp_command(@args);
				$self->_dunstify_pcrd($title, join '', @content);
			};
		}

		die "unknown type '$type' for gesture '$action'"
			unless $code;

		$feature->vars->{actions}{$action} = $code;
	}
}

sub set_gestures
{
	my ($self, $feature, $gesture) = @_;

	my $action = $feature->vars->{actions}{$gesture};
	if ($action) {
		$action->();
	}
	elsif ($feature->config->{notify}) {
		my $readable_gesture = join ' -> ', split //, uc $gesture;
		$self->_dunstify_pcrd('Unknown gesture', $readable_gesture);
	}

	return 1;
}

sub check_lock_screen
{
	my ($self, $feature) = @_;

	my $ex = PCRD::Util::try {
		PCRD::Util::slurp_command($feature->config->{command}, '-v');
	};

	return ['command', $ex] unless !$ex;
	return undef;
}

sub init_lock_screen
{
	my ($self, $feature) = @_;

	# after suspend, system clock will jump forward and $last_timestamp will be
	# far in the past - so the screen is locked very briefly after resume
	my $last_timestamp = time;
	my $timer = IO::Async::Timer::Periodic->new(
		interval => 60,
		reschedule => 'skip',
		on_tick => sub {
			if (time - $last_timestamp > 60 * $feature->config->{timeout}) {
				PCRD::Util::slurp_command($feature->config->{command});
			}

			$last_timestamp = time;
		},
	);

	$timer->start;
	$self->owner->loop->add($timer);
}

sub check_auto_suspend
{
	my ($self, $feature) = @_;

	return $self->check_dependency('Power.suspend')
		// $self->check_dependency('Device.lid')
		// undef;
}

sub init_auto_suspend
{
	my ($self, $feature) = @_;

	$feature->vars->{suspend} = $self->owner->module('Power')->feature('suspend');
	$feature->vars->{lid} = $self->owner->module('Device')->feature('lid');
	$feature->vars->{active} = !!1;
}

sub get_auto_suspend
{
	my ($self, $feature) = @_;

	return $feature->vars->{active};
}

sub set_auto_suspend
{
	my ($self, $feature, $value) = @_;

	if ($value eq 'on' || $value eq 'off') {
		$feature->vars->{active} = $value eq 'on';
		return 1;
	}

	return 0 unless $feature->vars->{active};
	my $lid_state = $feature->vars->{lid}->execute('r');
	return 0 if $lid_state;

	$feature->vars->{suspend}->execute('w', 1);
	return 1;
}

sub _build_features
{
	return {
		startup => {
			desc => 'perform actions on startup',
			mode => 'i',
			config => {
				notification => {
					desc => 'startup notification',
					value => 'PCRD,Loaded',
				},
			},
		},
		power => {
			desc => 'show notification about power',
			mode => 'i',
			config => {
				capacity => {
					desc => 'level of capacity at which to show notification',
					value => 15,
				},
			}
		},
		gestures => {
			desc => 'perform a gesture action',
			mode => 'w',
			config => {
				notify => {
					desc => 'whether to use notifications',
					value => 1,
				},
				action => {
					desc => 'key/value array of gesture actions (command, feature, notification)',
					value => {},
				},
			},
		},
		lock_screen => {
			desc => 'locks screen after long suspend',
			mode => 'i',
			config => {
				command => {
					desc => 'command to lock screen',
					value => 'slock',
				},
				timeout => {
					desc => 'suspend time until lock happens (minutes)',
					value => 5,
				},
			},
		},
		auto_suspend => {
			desc => 'suspends the device on lid close',
			mode => 'irw',
		},
	};
}

1;

