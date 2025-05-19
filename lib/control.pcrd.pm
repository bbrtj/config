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
	my ($self, $title, $content, $error) = @_;

	PCRD::Util::slurp_command(
		'dunstify',
		$title, $content,
		'-a', DUNST_APP,
		'-r', DUNST_ID,
		'-u', $error ? 'critical' : 'low'
	);
}

sub _dunstify_conf
{
	my ($self, $conf, $error) = @_;
	return unless defined $conf && length $conf;

	my ($title, $content) = split /,/, $conf;
	return $self->_dunstify($title, $content, $error);
}

sub init_startup
{
	my ($self, $feature) = @_;

	$self->_dunstify_conf($feature->{config}{notification});
}

sub prepare_gestures
{
	my ($self, $feature) = @_;

	my $actions = $feature->{config}{action} // {};
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
				$self->{pcrd}->module($module)->feature($feature)
					->execute($value ? ('w', $value) : ());
			};
		}
		elsif ($type eq 'notification') {
			my $title = shift @args;
			$code = sub {
				my $content = PCRD::Util::slurp_command(@args);
				$self->_dunstify($title, $content);
			};
		}

		die "unknown type '$type' for gesture '$action'"
			unless $code;

		$feature->{vars}{actions}{$action} = $code;
	}
}

sub set_gestures
{
	my ($self, $feature, $gesture) = @_;

	if ($feature->{vars}{actions}{$gesture}) {
		$feature->{vars}{actions}{$gesture}->();
	}
	elsif ($feature->{config}{notify}) {
		my $readable_gesture = join ' -> ', split //, uc $gesture;
		$self->_dunstify('Unknown gesture', $readable_gesture);
	}

	return 1;
}

sub check_lock_screen
{
	my ($self, $feature) = @_;

	my $ex = PCRD::Util::try {
		PCRD::Util::slurp_command($feature->{config}{command}, '-v');
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
			if (time - $last_timestamp > 60 * $feature->{config}{timeout}) {
				PCRD::Util::slurp_command($feature->{config}{command});
			}

			$last_timestamp = time;
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
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
	};
}

1;

