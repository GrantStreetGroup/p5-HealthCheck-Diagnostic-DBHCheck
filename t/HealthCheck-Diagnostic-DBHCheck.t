use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic::DBHCheck;
use DBI;
use DBD::SQLite;
use Scalar::Util qw( blessed );

my $bad_dbh          = qr/Valid 'dbh' is required at \S+ line \d+/;
my $expected_coderef = qr/The 'dbh' parameter should be a coderef/;

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

sub db_disconnect
{
    $db_param{dbh}->disconnect
        if (blessed $db_param{dbh} && $db_param{dbh}->can("disconnect"));
    undef %db_param;
}
eval { HealthCheck::Diagnostic::DBHCheck->check };
like $@, $bad_dbh, "Expected error with no DBH (as class)";

eval { HealthCheck::Diagnostic::DBHCheck->new->check };
like $@, $bad_dbh, "Expected error with no DBH";

eval { HealthCheck::Diagnostic::DBHCheck->new( dbh => {} )->check };
like $@, $expected_coderef, "Expected error with DBH as empty hashref";

eval { HealthCheck::Diagnostic::DBHCheck->check( dbh => bless {} ) };
like $@, $expected_coderef, "Expected error with DBH as empty blessed hashref";

eval { HealthCheck::Diagnostic::DBHCheck->check( dbh => sub {} ) };
like(
    $@,
    qr/The 'dbh' coderef should return a database handle/,
    "Expected error with DBH empty sub"
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
    "Expected error with both read_only and read_write";

$result = HealthCheck::Diagnostic::DBHCheck->new(
        dbh => \&db_connect
    )->check;
is( $result->{label},
    "dbh_check",
    "Expected label when connected without username"
);
is( $result->{status},
    "OK",
    "Expected result when connected without username",
);
like(
    $result->{info},
    qr/Successful (.+) read write check of (.+)/,
    "Expected info when connected without username",
);

$result = HealthCheck::Diagnostic::DBHCheck->check(
    dbh => sub { $db_param{dbh}->disconnect; return $db_param{dbh}; }
);

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

is( $result->{label},  "dbh_check", "Correct label" );
is( $result->{status}, "OK",        "Expected status" );
like(
    $result->{info},
    qr/Successful (.+) read write check of (.+) as (.+)/,
    "Expected info with username"
);

# Turn it into a coderef that returns a disconnected dbh
$result = HealthCheck::Diagnostic::DBHCheck->check(
    dbh => sub { $db_param{dbh}->disconnect; return $db_param{dbh}; }
);

is( $result->{status}, "CRITICAL", "Exptected status for disconnected handle" );
like(
    $result->{info},
    qr/Unsuccessful (.+) read write check of (.+) as (.+)/,
    "Expected info for disconnected handle"
);

done_testing;


