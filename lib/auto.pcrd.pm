package PCRD::Module::Any::Auto;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Auto';

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

