package Sentry;

sub new {
    my $class = shift;
    my $tree  = shift;
    return bless {tree => $tree}, $class;
}

sub DESTROY {
    my $self = shift;
    $self->{tree}->delete;
}

1