package PCRD::Module::Any::Dunst;

use v5.14;
use warnings;
use utf8;

use parent 'PCRD::Module';

use constant name => 'Dunst';

use constant DUNST_APP => 'pcrd';
use constant DUNST_ID => 92137;

sub _dunstify
{
	my ($self, $title, $content, %args) = @_;

	return $self->owner->broadcast(
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

sub _dunstify_pcrd_input
{
	my ($self, $conf, $error) = @_;
	return unless defined $conf && length $conf;

	my ($title, $content) = split /,/, $conf, 2;
	return $self->_dunstify_pcrd($title, $content, $error);
}

sub set_info
{
	my ($self, $feature, $value) = @_;

	return $self->_dunstify_pcrd_input($value, 0)
		->then(sub { 1 });
}

sub set_error
{
	my ($self, $feature, $value) = @_;

	return $self->_dunstify_pcrd_input($value, 1)
		->then(sub { 1 });
}

sub _build_features
{
	return {
		info => {
			desc => 'create a dunst info notification',
			mode => 'w',
			needs_agent => 1,
		},
		error => {
			desc => 'create a dunst error notification',
			mode => 'w',
			needs_agent => 1,
		},
	};
}

1;

