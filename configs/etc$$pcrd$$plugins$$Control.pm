package PCRD::Module::Any::Control;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Control';

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

sub init_power
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	my $initialized = exists $vars->{running};
	$vars->{running} = $enabled;
	return if $initialized;

	$vars->{last_battery} = 100;
	$vars->{notified} = 0;
	$vars->{last_charging} = 0;
	$feature->dependencies->{'Power.capacity'}->add_execute_hook(
		sub {
			my ($action, $value, $result) = @_;
			my $config = $feature->config;

			return unless $vars->{running};

			my $old = $vars->{last_battery};
			if ($result != $old) {
				$vars->{last_battery} = $result;

				if (!$vars->{notified} && $result <= $config->{capacity}) {
					$feature->dependencies->{'Dunst.error'}->execute('w', "Low power,Battery at $result%");
					$vars->{notified} = 1;
				}
				elsif ($result > $config->{capacity}) {
					$vars->{notified} = 0;
				}
			}
		}
	);

	$feature->dependencies->{'Power.charging'}->add_execute_hook(
		sub {
			my ($action, $value, $result) = @_;

			return unless $vars->{running};

			if (!!$result != $vars->{last_charging}) {
				$vars->{last_charging} = !!$result;

				my $text = $result ? 'charging' : 'discharging';
				my $title = ucfirst $text;
				$feature->dependencies->{'Dunst.info'}->execute('w', "$title,Device is now $text");
			}
		}
	);
}

sub prepare_gestures
{
	my ($self, $feature) = @_;

	my $actions = $feature->config->{action} // {};
	foreach my $action (keys %{$actions}) {
		$feature->vars->{actions}{$action} = $self->_make_action($feature, $actions->{$action});
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
		$feature->dependencies->{'Dunst.info'}->execute('w', "Unknown gesture,$readable_gesture");
	}

	return PCRD::Bool->new(!!1);
}

sub init_kblayout
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	return unless $enabled;
	return unless defined $vars->{current};

	# set layout on startup
	$feature->execute('w', $vars->{current});
}

sub prepare_kblayout
{
	my ($self, $feature) = @_;
	my $vars = $feature->vars;

	my $last_order = 0;
	my $layouts = $feature->config->{layouts} // {};
	foreach my $layout_name (sort keys %{$layouts}) {
		my $layout = $layouts->{$layout_name};

		if (!$layout->{layout}) {
			say "no keyboard layout specified for $layout_name - skipping";
			next;
		}

		push @{$vars->{layouts}}, $layout;
		$layout->{order} //= $last_order;
		$layout->{name} = $layout_name;
		$last_order += 1;
	}

	@{$vars->{layouts}} = sort { $a->{order} <=> $b->{order} }
		@{$vars->{layouts}};
	%{$vars->{layouts_map}} = map { $vars->{layouts}[$_]{name} => $_ }
		keys @{$vars->{layouts}};
	$vars->{current} = $vars->{layouts}[0]{name}
		if @{$vars->{layouts}} > 0;
}

sub set_kblayout
{
	my ($self, $feature, $layout) = @_;
	my $vars = $feature->vars;

	PCRD::X::ExecutionFailed->raise('no keyboard layouts defined')
		unless @{$vars->{layouts}} > 0;

	my $layout_ind;
	if ($layout eq 'next') {
		$layout_ind = $vars->{layouts_map}{$vars->{current}};
		$layout_ind = ($layout_ind + 1) % @{$vars->{layouts}};
	}
	else {
		$layout_ind = $vars->{layouts_map}{$layout};
		PCRD::X::BadArgument->raise("invalid layout $layout")
			unless defined $layout_ind;
	}

	my $conf = $vars->{layouts}[$layout_ind];
	$vars->{current} = $conf->{name};
	my @args = (
		'setxkbmap',
		'-layout',
		$conf->{layout},
		($conf->{variant}
			? ('-variant', $conf->{variant})
			: ()
		),
		($conf->{option}
			? ('-option', $conf->{option})
			: ()
		),
	);

	return $self->owner->broadcast(@args)
		->then(sub { PCRD::Bool->new(!!1) });
}

sub init_wallpapers
{
	my ($self, $feature, $enabled) = @_;
	my $vars = $feature->vars;

	return unless $enabled;
	return unless defined $vars->{current};

	# set wallpaper on startup
	$feature->execute('w', 'refresh');
}

sub prepare_wallpapers
{
	my ($self, $feature) = @_;

	$feature->vars->{current} = $feature->config->{default};
}

sub set_wallpapers
{
	my ($self, $feature, $wallpaper) = @_;

	$wallpaper = $feature->vars->{current}
		if $wallpaper eq 'refresh';

	my $wallpaper_path = $feature->config->{directory} . '/' . $wallpaper;
	PCRD::X::BadArgument->raise("wallpaper $wallpaper_path does not exist")
		unless -f $wallpaper_path;

	$feature->vars->{current} = $wallpaper;
	my @args = ('feh', '--bg-scale', $wallpaper_path);

	return $self->owner->broadcast(@args)
		->then(sub { PCRD::Bool->new(!!1) });
}


sub prepare_auto_suspend
{
	my ($self, $feature) = @_;

	$feature->vars->{active} = !!1;
}

sub get_auto_suspend
{
	my ($self, $feature) = @_;

	return PCRD::Bool->new($feature->vars->{active});
}

sub set_auto_suspend
{
	my ($self, $feature, $value) = @_;
	state $validator = PCRD::Util::generate_validator(truefalse => 1, custom => ['suspend']);
	$validator->($value);

	my $bool = PCRD::Util::value_to_bool($value);
	if (defined $bool) {
		$feature->vars->{active} = $bool;
		return PCRD::Bool->new(!!1);
	}

	return PCRD::Bool->new(!!0) unless $value eq 'suspend';
	return PCRD::Bool->new(!!0) unless $feature->vars->{active};

	$feature->dependencies->{'Device.lid'}->execute('r')
		->then(
			sub {
				my $lid_state = shift;
				return PCRD::Bool->new(!!0) if $lid_state;
				return $feature->dependencies->{'Device.suspend'}->execute('w', PCRD::Bool->new(!!1));
			}
		);
}

sub _build_features
{
	return {
		power => {
			desc => 'show notification about power',
			mode => 'i',
			config => {
				capacity => {
					desc => 'level of capacity at which to show notification',
					value => 15,
				},
			},
			dependencies => [
				'Power.capacity',
				'Power.charging',
				'Dunst.info',
				'Dunst.error',
			],
			needs_agent => 1,
		},
		kblayout => {
			desc => 'switch a keyboard layout',
			mode => 'iw',
			config => {
				layouts => {
					desc => 'key/value array of layouts to use (layout,variant,option,order)',
					value => {},
				},
			},
			needs_agent => 1,
		},
		wallpapers => {
			desc => 'control the wallpapers',
			mode => 'iw',
			config => {
				directory => {
					desc => 'directory with the wallpapers',
					value => '/usr/share/wallpapers',
				},
				default => {
					desc => 'default wallpaper',
				},
			},
			needs_agent => 1,
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
					desc => 'key/value array of gesture actions (command/feature/notification/info)',
					value => {},
				},
			},
			dependencies => [
				'Dunst.info',
			],
			needs_agent => 1,
		},
		auto_suspend => {
			desc => 'suspends the device on lid close',
			mode => 'rw',
			dependencies => [
				'Device.suspend',
				'Device.lid',
			],
		},
	};
}
1;

