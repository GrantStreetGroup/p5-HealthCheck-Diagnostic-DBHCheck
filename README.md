# SYNOPSIS

    my $health_check = HealthCheck->new( checks => [
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh       => \&connect_to_read_write_db,
            db_access => "rw",
            tags      => [qw< dbh_check_rw >]
        ),
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh       => \&connect_to_read_only_db,
            db_access => "ro",
            tags      => [qw< dbh_check_ro >]
        ),
    ] );

    my $result = $health_check->check;
    $result->{status}; # OK on a successful check or CRITICAL otherwise

# DESCRIPTION

Determines if the database can be used for read and write access, or read only
access.

For read access, a simple SELECT statement is used.

For write access, a temporary table is created, and used for testing.

# ATTRIBUTES

Those inherited from ["ATTRIBUTES" in HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck::Diagnostic#ATTRIBUTES) plus:

## dbh

A coderef that returns a
[DBI DATABASE handle object](https://metacpan.org/pod/DBI#DBI-DATABSE-HANDLE-OBJECTS)
or optionally the handle itself.

Can be passed either to `new` or `check`.

## db\_access

A string indicating the type of access being tested.

A value of `ro` indicates only read access shoud be tested.

A value of `rw` indicates both read and write access should be tested.

DEFAULT is `rw`.

## db\_class

The expected class for the database handle returned by the `dbh` coderef.

Defaults to `DBI::db`.

# DEPENDENCIES

[HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck::Diagnostic)

# CONFIGURATION AND ENVIRONMENT

None
