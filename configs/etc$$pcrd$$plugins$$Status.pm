package PCRD::Module::Any::Status;

use v5.14;
use warnings;
use utf8;

use IO::Async::Timer::Periodic;
use Future;
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
	my $f_life = $feature->dependencies->{'Power.life'}->execute('r');
	my $f_capacity = $feature->dependencies->{'Power.capacity'}->execute('r');
	my $f_charging = $feature->dependencies->{'Power.charging'}->execute('r');

	return Future->wait_all($f_life, $f_capacity, $f_charging)->then(
		sub {
			my $battery_life = $f_life->get;
			my $battery_capacity = $f_capacity->get;
			my $battery_charging = $f_charging->get;
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
	);
}

sub sound_status
{
	my ($self, $feature) = @_;

	state $sound_levels = ['', '', '', ''];
	state $colors = [COLOR_DIMMED, COLOR_SELECTED, COLOR_SELECTED, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];

	my $color;
	my $level;

	my $f_mute = $feature->dependencies->{'Sound.mute'}->execute('r');
	my $f_volume = $feature->dependencies->{'Sound.volume'}->execute('r');

	return Future->wait_all($f_mute, $f_volume)->then(
		sub {
			if ($f_mute->get) {
				$color = COLOR_DIMMED;
				$level = '';
				return _colsym("$color$level", 'mute');
			}
			else {
				my $volume = $f_volume->get;
				return undef
					unless $volume >= 0;

				$volume *= 100;
				my $index = int($volume / 25 - 0.01); # minus 0.01 to have 100 as non-alert
				$level = $sound_levels->[$index > $#$sound_levels ? $#$sound_levels : $index];
				$color = $colors->[$index > $#$colors ? $#$colors : $index];

				return _colsym("$color$level", $volume);
			}
		}
	);
}

sub memory_status
{
	my ($self, $feature) = @_;

	state $ram_indicator = '';
	state $colors = [COLOR_DIMMED, COLOR_SUCCESS, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];
	my $f_memory = $feature->dependencies->{'Performance.memory'}->execute('r');
	my $f_swap = $feature->dependencies->{'Performance.swap'}->execute('r');

	return Future->wait_all($f_memory, $f_swap)->then(
		sub {
			my $memory = $f_memory->get * 100;
			my $swap = $f_swap->get * 100;
			my $color_index = int(($memory + $swap) / 25);
			my $color = $colors->[$color_index > $#$colors ? $#$colors : $color_index];

			return sprintf _colsym("%s%s", '%.1f', '%s%.1f'), $color, $ram_indicator, $memory, COLOR_DIMMED, $swap;
		}
	);
}

sub cpu_status
{
	my ($self, $feature) = @_;

	state $cpu_indicator = '';
	state $colors = [COLOR_DIMMED, COLOR_SUCCESS, COLOR_SELECTED, COLOR_ALERT, COLOR_URGENT];

	return $feature->dependencies->{'Performance.cpu'}->execute('r')->then(
		sub {
			my $cpu = shift;

			return undef unless $cpu >= 0;

			$cpu *= 100;
			my $color_index = int($cpu / 10);
			my $color = $colors->[$color_index > $#$colors ? $#$colors : $color_index];

			return sprintf _colsym("%s%s", '%.1f'), $color, $cpu_indicator, $cpu;
		}
	);
}

sub time_status
{
	my ($self, $feature) = @_;

	state $time_symbol = '';

	return $feature->dependencies->{'System.time'}->execute('r')->then(
		sub {
			my $time = shift;
			return _colsym(COLOR_SELECTED . $time_symbol, $time);
		}
	);
}

sub date_status
{
	my ($self, $feature) = @_;

	state $date_symbol = '';
	return $feature->dependencies->{'System.date'}->execute('r')->then(
		sub {
			my $date = shift;
			return _colsym(COLOR_SELECTED . $date_symbol, $date);
		}
	);
}

sub uptime_status
{
	my ($self, $feature) = @_;

	state $uptime_symbol = '';
	return $feature->dependencies->{'System.uptime'}->execute('r')->then(
		sub {
			my $uptime = shift;
			return _colsym(COLOR_SELECTED . $uptime_symbol, $uptime);
		}
	);

}

sub init_build_default_line
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	my $initialized = exists $vars->{running};
	$vars->{running} = $enabled;
	return if $initialized;

	$self->{next_build} = 0;

	my $timer = IO::Async::Timer::Periodic->new(
		interval => 1,
		reschedule => 'skip',
		on_tick => sub {
			$feature->execute('w', 'auto')
				if $vars->{running};
		},
	);

	$timer->start;
	$self->owner->notifier->add_child($timer);

	my $sound_change = sub {
		my ($action, $value) = @_;
		if ($action eq 'w') {
			$feature->execute('w', 'sound changed')
				if $vars->{running};
		}
	};

	$feature->dependencies->{'Sound.volume'}->add_execute_hook($sound_change);
	$feature->dependencies->{'Sound.mute'}->add_execute_hook($sound_change);
}

sub set_build_default_line
{
	my ($self, $feature, $value) = @_;

	return 0 if $value eq 'auto' && time < $self->{next_build};

	my @futures = (
		$self->battery_status($feature),
		$self->sound_status($feature),
		$self->memory_status($feature),
		$self->cpu_status($feature),
	);

	return Future->wait_all(@futures)->then(
		sub {
			$self->{next_build} = time + $feature->config->{interval};
			$self->set_dwm_line(map { $_->get } @futures);

			return 1;
		}
	);
}

sub set_build_time_line
{
	my ($self, $feature, $value) = @_;

	my @futures = (
		$self->time_status($feature),
		$self->date_status($feature),
		$self->uptime_status($feature),
	);

	return Future->wait_all(@futures)->then(
		sub {
			$self->{next_build} = time + $feature->config->{duration};
			$self->set_dwm_line(map { $_->get } @futures);

			return 1;
		}
	);
}

sub _build_features
{
	return {
		build_default_line => {
			desc => 'builds the default line',
			mode => 'iw',
			config => {
				interval => {
					desc => 'interval for updating the bar',
					value => 5,
				},
			},
			dependencies => [
				'Power.capacity',
				'Power.life',
				'Power.charging',
				'Performance.memory',
				'Performance.swap',
				'Performance.cpu',
				'Sound.volume',
				'Sound.mute',
			],
			needs_agent => 1,
		},
		build_time_line => {
			desc => 'builds time line',
			mode => 'w',
			config => {
				duration => {
					desc => 'duration for showing the time',
					value => 8,
				},
			},
			dependencies => [
				'System.date',
				'System.time',
				'System.uptime',
			],
			needs_agent => 1,
		},
	};
}

1;

