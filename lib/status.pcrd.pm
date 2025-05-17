package PCRD::Module::Any::Status;

use v5.14;
use warnings;
use utf8;

use IO::Async::Timer::Periodic;
use Time::HiRes qw(time);

use parent 'PCRD::Module';

use constant name => 'Status';

use constant {
	COLOR_NORMAL => "\x01",
	COLOR_DIMMED => "\x04",
	COLOR_SELECTED => "\x05",
	COLOR_SUCCESS => "\x06",
	COLOR_ALERT => "\x07",
	COLOR_URGENT => "\x08",
};

sub _colsym
{
	return shift() . ' ' . COLOR_NORMAL . join ' ', @_;
}

sub set_dwm_line
{
	my ($self, @parts) = @_;
	my $col_sep = COLOR_DIMMED;
	my $sep = " $col_sep・ ";
	my $text = join $sep, grep { defined } @parts;

	system('xsetroot', '-name', $text);
}

sub battery_status
{
	my ($self, $feature) = @_;

	state $battery_levels = ['', '', '', '', ''];
	state $colors = [COLOR_URGENT, COLOR_ALERT, COLOR_SELECTED, COLOR_SUCCESS, COLOR_SUCCESS];
	my $battery_life = $feature->{vars}{life}->execute('r');
	my $battery_capacity = $feature->{vars}{capacity}->execute('r');
	my $battery_charging = $feature->{vars}{charging}->execute('r');
	my $battery = '';

	my $index = -1;
	if (!$battery_charging) {
		my $result = $battery_capacity > 0 ? int(log($battery_capacity) / log(2)) : 0;
		$index = $result > 3 ? $result - 3 : 0;
	}

	my $level = $battery_levels->[$index];
	my $color = $colors->[$index];
	$battery = _colsym("$color$level", $battery_capacity);

	if ($battery_life >= 0) {
		my $hours = int($battery_life / 60);
		my $minutes = $battery_life % 60;
		$battery = sprintf "%s %s%d:%02d", $battery, COLOR_DIMMED, $hours, $minutes;
	}

	return $battery;
}

sub sound_status
{
	my ($self, $feature) = @_;

	state $sound_levels = ['', '', '', ''];
	state $colors = [COLOR_DIMMED, COLOR_SELECTED, COLOR_SELECTED, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];
	my $volume = $feature->{vars}{volume}->execute('r');

	return undef
		unless $volume >= 0;

	$volume *= 100;
	my $index = int($volume / 25 - 0.01); # minus 0.01 to have 100 as non-alert
	my $level = $sound_levels->[$index > $#$sound_levels ? $#$sound_levels : $index];
	my $color = $colors->[$index > $#$colors ? $#$colors : $index];

	return _colsym("$color$level", $volume);
}

sub memory_status
{
	my ($self, $feature) = @_;

	state $ram_indicator = '';
	state $colors = [COLOR_DIMMED, COLOR_SUCCESS, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];
	my $memory = $feature->{vars}{memory}->execute('r');
	my $swap = $feature->{vars}{swap}->execute('r');

	$memory *= 100;
	$swap *= 100;
	my $color_index = int(($memory + $swap) / 25);
	my $color = $colors->[$color_index > $#$colors ? $#$colors : $color_index];

	return sprintf _colsym("%s%s", '%.1f', '%s%.1f'), $color, $ram_indicator, $memory, COLOR_DIMMED, $swap;
}

sub cpu_status
{
	my ($self, $feature) = @_;

	state $cpu_indicator = '';
	state $colors = [COLOR_DIMMED, COLOR_SUCCESS, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];
	my $cpu = $feature->{vars}{cpu}->execute('r');

	return undef unless $cpu >= 0;

	$cpu *= 100;
	my $color_index = int($cpu / 10);
	my $color = $colors->[$color_index > $#$colors ? $#$colors : $color_index];

	return sprintf _colsym("%s%s", '%.1f'), $color, $cpu_indicator, $cpu;
}

sub time_status
{
	my ($self, $feature) = @_;

	state $time_symbol = '';
	my $time = $feature->{vars}{time}->execute('r');

	return _colsym(COLOR_SELECTED . $time_symbol, $time);
}

sub date_status
{
	my ($self, $feature) = @_;

	state $date_symbol = '';
	my $date = $feature->{vars}{date}->execute('r');

	return _colsym(COLOR_SELECTED . $date_symbol, $date);
}

sub uptime_status
{
	my ($self, $feature) = @_;

	state $uptime_symbol = '';
	my $uptime = $feature->{vars}{uptime}->execute('r');

	return _colsym(COLOR_SELECTED . $uptime_symbol, $uptime);
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
			if (time - $last_timestamp > 60 * 15) {
				PCRD::Util::slurp_command($feature->{config}{command});
			}

			$last_timestamp = time;
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
}

sub check_build_default_line
{
	my ($self, $feature) = @_;

	return $self->check_dependency('Power.capacity')
		// $self->check_dependency('Power.life')
		// $self->check_dependency('Power.charging')
		// $self->check_dependency('Performance.memory')
		// $self->check_dependency('Performance.swap')
		// $self->check_dependency('Performance.cpu')
		// $self->check_dependency('Sound.volume')
		// undef;
}

sub init_build_default_line
{
	my ($self, $feature) = @_;

	$feature->{vars}{capacity} = $self->{pcrd}->module('Power')->feature('capacity');
	$feature->{vars}{life} = $self->{pcrd}->module('Power')->feature('life');
	$feature->{vars}{charging} = $self->{pcrd}->module('Power')->feature('charging');
	$feature->{vars}{memory} = $self->{pcrd}->module('Performance')->feature('memory');
	$feature->{vars}{swap} = $self->{pcrd}->module('Performance')->feature('swap');
	$feature->{vars}{cpu} = $self->{pcrd}->module('Performance')->feature('cpu');
	$feature->{vars}{volume} = $self->{pcrd}->module('Sound')->feature('volume');
	$self->{next_build} = 0;

	my $timer = IO::Async::Timer::Periodic->new(
		interval => 1,
		reschedule => 'skip',
		on_tick => sub {
			$feature->execute('w', 'auto');
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);

	$feature->{vars}{volume}->{execute_hook} = sub {
		my ($action, $value) = @_;
		if ($action eq 'w') {
			$feature->execute('w', 'volume changed');
		}
	};
}

sub set_build_default_line
{
	my ($self, $feature, $value) = @_;

	return 0 if $value eq 'auto' && time < $self->{next_build};

	my @status_line = (
		$self->battery_status($feature),
		$self->sound_status($feature),
		$self->memory_status($feature),
		$self->cpu_status($feature),
	);

	$self->{next_build} = time + $feature->{config}{interval};
	$self->set_dwm_line(@status_line);

	return 1;
}

sub check_build_time_line
{
	my ($self, $feature) = @_;

	return $self->check_dependency('System.date')
		// $self->check_dependency('System.time')
		// $self->check_dependency('System.uptime')
		// $self->check_dependency('Performance.storage')
		// undef;
}

sub init_build_time_line
{
	my ($self, $feature) = @_;

	$feature->{vars}{time} = $self->{pcrd}->module('System')->feature('time');
	$feature->{vars}{date} = $self->{pcrd}->module('System')->feature('date');
	$feature->{vars}{uptime} = $self->{pcrd}->module('System')->feature('uptime');
}

sub set_build_time_line
{
	my ($self, $feature, $value) = @_;

	my @status_line = (
		$self->time_status($feature),
		$self->date_status($feature),
		$self->uptime_status($feature),
	);

	$self->{next_build} = time + $feature->{config}{duration};
	$self->set_dwm_line(@status_line);

	return 1;
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
			},
		},
		build_default_line => {
			desc => 'builds the default line',
			mode => 'iw',
			config => {
				interval => {
					desc => 'interval for updating the bar',
					value => 5,
				},
			},
		},
		build_time_line => {
			desc => 'builds time line',
			mode => 'iw',
			config => {
				duration => {
					desc => 'duration for showing the time',
					value => 8,
				},
			},
		},
	};
}

1;

