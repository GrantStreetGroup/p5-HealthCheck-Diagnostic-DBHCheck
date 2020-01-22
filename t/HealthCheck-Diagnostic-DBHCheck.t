use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic::DBHCheck;
use DBI;
use DBD::SQLite;
use Scalar::Util qw( blessed );

#-------------------------------------------------------------------------------
#     FUNCTION: db_connect
#  DESCRIPTION: Helper function to connect to a test database. Will default to
#               using SQLite, but can be overridden with environment variables.
#   PARAMETERS: NONE
#      RETURNS: NONE
#     COMMENTS: DBITEST_DSN    - Override the DB DSN
#               DBITEST_DBUSER - Override the DB user name
#               DBITEST_DBPASS - Override the DB password
#-------------------------------------------------------------------------------
our %db_param;
sub db_connect
{
    my $dsn  =  $ENV{DBITEST_DSN} //
                $db_param{dsn}    //
                "dbi:SQLite:dbname=:memory:";
    my $user =  $ENV{DBITEST_DBUSER} //
                $db_param{dbuser}    //
                "";
    my $pass =  $ENV{DBITEST_DBPASS} //
                $db_param{dbpass}    //
                "";

    $db_param{dbh} = DBI->connect(
        $dsn,
        $user,
        $pass,
        {
            RaiseError => 0, # For tests, just be quiet
            PrintError => 0, # For tests, just be quiet
        }
    );
    return $db_param{dbh};
}

#-------------------------------------------------------------------------------
# Tests begin here
#-------------------------------------------------------------------------------
my $bad_dbh          = qr/Valid 'dbh' is required at \S+ line \d+/;
my $expected_coderef = qr/The 'dbh' parameter should be a coderef/;
my $bad_dbh_params   = qr/Could not connect to the DB or params are invalid/;
my $critical_status  = qr/CRITICAL/;
my $unknown_status   = qr/UNKNOWN/;
my $r = undef;

eval { HealthCheck::Diagnostic::DBHCheck->check };
like $@, $bad_dbh, "Expected error with no DBH (as class)";

eval { HealthCheck::Diagnostic::DBHCheck->new->check };
like $@, $bad_dbh, "Expected error with no DBH";

eval { HealthCheck::Diagnostic::DBHCheck->new( dbh => {} )->check };
like $@, $expected_coderef, "Expected error with DBH as empty hashref";

eval { HealthCheck::Diagnostic::DBHCheck->check( dbh => bless {} ) };
like $@, $expected_coderef, "Expected error with DBH as empty blessed hashref";

eval { $r = HealthCheck::Diagnostic::DBHCheck->check( dbh => sub {} ) };
like(
    $r->{info},
    qr/The 'dbh' coderef should return an object/,
    "Expected error with DBH empty sub"
);
like (
    $r->{status},
    $unknown_status,
    "Expected error with DBH empty sub to provide status of UNKNOWN"
);

eval {
    $r = HealthCheck::Diagnostic::DBHCheck->check(
        dbh => sub { die "params no good"; }
    )
};
like (
    $r->{status},
    $critical_status,
    "Expected bad DBH params to provide status of CRITICAL"
);
like (
    $r->{info},
    $bad_dbh_params, "Expected error with bad DBH params"
);

eval {
    $r = HealthCheck::Diagnostic::DBHCheck->check(
        dbh => sub { return "foobar"; }
    )
};
like(
    $r->{info},
    qr/The 'dbh' coderef should return an object/,
    "Expected error with DBH returning a scalar"
);
like(
    $r->{status},
    $unknown_status,
    "Expected error with DBH returning a scalar to provide status of UNKNOWN"
);

eval {
    $r = HealthCheck::Diagnostic::DBHCheck->check(
        dbh => sub { return bless {}, "Foo::Bar"; }
    )
};
like(
    $r->{info},
    qr/The 'dbh' coderef should return a '.*', not a 'Foo::Bar'/,
    "Expected error with DBH returning an unexpected class of object"
);
like(
    $r->{status},
    $unknown_status,
    "Expected unknown status with the error for DBH returning unexpected class"
);

my $result;

eval {
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh       => \&db_connect,
            db_access => "everything",
        )->check;
    };

like
    $@,
    qr/value '.*' is not valid for the 'db_access' parameter/,
    "Expected error with invalid 'db_access'";

$result = HealthCheck::Diagnostic::DBHCheck->new(
        dbh => \&db_connect
    )->check;
note explain $result;
is( $result->{label},
    "dbh_check",
    "Expected label for read write test without username"
);
is( $result->{status},
    "OK",
    "Expected result for read write test without username",
);
like(
    $result->{info},
    qr/Successful (.+) read write check of (.+)/,
    "Expected info for read write test without username",
);

$result = HealthCheck::Diagnostic::DBHCheck->new(
        dbh       => \&db_connect,
        db_access => "ro",
    )->check;
note explain $result;
is( $result->{label},
    "dbh_check",
    "Expected label for read only test without username"
);
is( $result->{status},
    "OK",
    "Expected result for read only test without username",
);
like(
    $result->{info},
    qr/Successful (.+) read only check of (.+)/,
    "Expected info for read only test without username",
);

$result = HealthCheck::Diagnostic::DBHCheck->check(
    dbh => sub { $db_param{dbh}->disconnect; return $db_param{dbh}; }
);
note explain $result;

is( $result->{status}, "CRITICAL", "Expected status for disconnected dbh");

like(
    $result->{info},
    qr/Unsuccessful \S+ read write check of \S+/,
    "Expected info for disconnected dbh"
);


# Now try it with a username
$db_param{dbuser} = "FakeUser";

$result = HealthCheck::Diagnostic::DBHCheck->new(
        dbh => \&db_connect
    )->check;
note explain $result;

is( $result->{label},  "dbh_check", "Correct label" );
is( $result->{status}, "OK",        "Expected status" );
like(
    $result->{info},
    qr/Successful (.+) read write check of (.+) as (.+)/,
    "Expected info for read write with username"
);

# Turn it into a coderef that returns a disconnected dbh
$result = HealthCheck::Diagnostic::DBHCheck->check(
    dbh => sub { $db_param{dbh}->disconnect; return $db_param{dbh}; }
);
note explain $result;

is( $result->{status}, "CRITICAL", "Expected status for disconnected handle" );
like(
    $result->{info},
    qr/Unsuccessful (.+) read write check of (.+) as (.+)/,
    "Expected info for disconnected handle"
);

done_testing;
