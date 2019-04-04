package HealthCheck::Diagnostic::DBHCheck;

# ABSTRACT: Check a database handle to make sure you have read/write access
# VERSION

use 5.010;
use strict;
use warnings;
use parent 'HealthCheck::Diagnostic';

use Carp;

sub new {
    my ($class, @params) = @_;

    # Allow either a hashref or even-sized list of params
    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    croak("The 'dbh' parameter should be a coderef!")
      if ($params{dbh} && (ref $params{dbh} ne "CODE"));

    return $class->SUPER::new(
        label => 'dbh_check',
        %params
    );
}

sub check {
    my ( $self, %params ) = @_;

   # 1st, try to get dbh from provided parameters
    my $dbh = $params{dbh};
    # 2nd, if invoked with an object (not the class), then get dbh from object
    $dbh ||= $self->{dbh} if ref $self;

    croak("Valid 'dbh' is required") unless $dbh;

    croak("The 'dbh' parameter should be a coderef!")
        unless (ref $dbh eq "CODE");

    $dbh = $dbh->(%params);

    my $isa = ref $dbh;

    croak("The 'dbh' coderef should return a database handle, not a '$isa'")
        unless ($isa =~ /^DBI/);

    my $read_only  = $params{read_only}  // ((ref $self) && $self->{read_only});
    my $read_write = $params{read_write} // ((ref $self) && $self->{read_write});

    croak("The 'read_only' and 'read_write' parameters are mutually exclusive")
        if ($read_only && $read_write);

    my $res = $self->SUPER::check( %params, dbh => $dbh );
    delete $res->{dbh};    # don't include the object in the result

    return $res;
}


sub _read_write_temp_table {
    my (%params) = @_;
    my $dbh      = $params{dbh};
    my $table    = $params{table_name} // "__DBH_CHECK__";
    my $status   = "CRITICAL";

    my $qtable   = $dbh->quote_identifier($table);

    # Drop it like its hot
    $dbh->do("DROP TABLE IF EXISTS $qtable");

    $dbh->do(
        join(
            "", 
            "CREATE TEMPORARY TABLE IF NOT EXISTS $qtable (",
            "check_id INTEGER PRIMARY KEY,",
            "check_string VARCHAR(64) NOT NULL",
            ")"
        )
    );

    $dbh->do(
        join(
            "",
            "INSERT INTO $qtable ",
            "       (check_id, check_string) ",
            "VALUES (1,        'Hello world')",
        )
    );
    my @row = $dbh->selectrow_array(
        "SELECT check_string FROM $qtable WHERE check_id = 1"
    );

    $status = "OK" if ($row[0] && ($row[0] eq "Hello world"));

    $dbh->do("DROP TABLE $qtable");

    return $status;
}

sub run {
    my ( $self, %params ) = @_;
    my $dbh = $params{dbh};

    # Get readonly from parameters or object
    my $read_only = $params{read_only} // ((ref $self) && $self->{read_only});

    # See if a simple SELECT works
    my $value  = eval { $dbh->selectrow_array("SELECT 1"); };
    my $status = (defined($value) && ($value == 1)) ? "OK" : "CRITICAL";

    $status = _read_write_temp_table(%params)
        if (($status eq "OK") && !$read_only);

    # Generate the human readable info string
    my $info = sprintf(
        "%s %s %s check of %s%s",
        $status eq "OK" ? "Successful" : "Unsuccessful",
        $dbh->{Driver}->{Name},
        $read_only ? "read only" : "read write",
        $dbh->{Name},
        $dbh->{Username} ? " as $dbh->{Username}" : "",
    );

    return { status => $status, info => $info };
}

1;
__END__

=head1 SYNOPSIS

    my $health_check = HealthCheck->new( checks => [
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh => \&connect_to_read_write_db,
            tags => [qw< dbh_check_rw >]
        ),
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh => \&connect_to_read_only_db,
            tags => [qw< dbh_check_ro >]
        ),
    ] );

    my $result = $health_check->check;
    $result->{status}; # OK on a successful check or CRITICAL otherwise

=head1 DESCRIPTION

Determines if the database can be used for read and write access, or read only
access.

For C<read_only> access, a simple SELECT statement is used.

For C<reaad_write> access, a temporary table is created, and used for testing.

=head1 ATTRIBUTES

Those inherited from L<HealthCheck::Diagnostic/ATTRIBUTES> plus:

=head2 dbh

A coderef that returns a
L<DBI database handle object|DBI/DBI-DATABSE-HANDLE-OBJECTS>
or optionally the handle itself.

Can be passed either to C<new> or C<check>.

=head2 read_only

A boolean value indicating if only the read access should be tested.
B<NOTE:> Cannot be used when C<read_write> is true.

=head2 read_write

A boolean value indicating if boteh read and write access should be tested.
B<NOTE:> Cannot be used when C<read_only> is true.

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>

=head1 CONFIGURATION AND ENVIRONMENT

None

=cut

