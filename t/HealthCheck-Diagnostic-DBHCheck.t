use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic::DBHCheck;
use DBI;
use DBD::SQLite;

my $bad_dbh = qr/Valid 'dbh' is required at \S+ line \d+/;

eval { HealthCheck::Diagnostic::DBHCheck->check };
like $@, $bad_dbh, "Expected error with no DBHi (as class)";

eval { HealthCheck::Diagnostic::DBHCheck->new->check };
like $@, $bad_dbh, "Expected error with no DBH";

eval { HealthCheck::Diagnostic::DBHCheck->new( dbh => {} )->check };
like $@, $bad_dbh, "Expected error with DBH as empty hashref";

eval { HealthCheck::Diagnostic::DBHCheck->check( dbh => bless {} ) };
like $@, $bad_dbh, "Expected error with DBH as empty blessed hashref";

eval { HealthCheck::Diagnostic::DBHCheck->check( dbh => sub {} ) };
like $@, $bad_dbh, "Expected error with DBH empty sub";

my $dbname = 'dbname=:memory:';
my $dbh = DBI->connect("dbi:SQLite:$dbname","","", { PrintError => 0 });

eval {
        HealthCheck::Diagnostic::DBHCheck->new(
            dbh        => $dbh,
            read_only  => 1,
            read_write => 1
        )->check;
    };

like
    $@,
    qr/mutually exclusive/,
    "Expected error with both read_only and read_write";

is_deeply( HealthCheck::Diagnostic::DBHCheck->new( dbh => $dbh )->check, {
    label  => 'dbh_check',
    status => 'OK',
    info   => "Successful SQLite read write check of $dbname",
}, "OK status as expected" );

$dbh->disconnect;
is_deeply( HealthCheck::Diagnostic::DBHCheck->check( dbh => $dbh ), {
    status => 'CRITICAL',
    info   => "Unsuccessful SQLite read write check of dbname=:memory:",
}, "CRITICAL status as expected" );

is_deeply( HealthCheck::Diagnostic::DBHCheck->check( dbh => $dbh, read_only => 1 ), {
    status => 'CRITICAL',
    info   => "Unsuccessful SQLite read only check of dbname=:memory:",
}, "CRITICAL status as expectedi with read_only set" );

# Now try it with a username and a coderef
$dbh = sub {
    DBI->connect("dbi:SQLite:$dbname","FakeUser","", { PrintError => 0 })
};

is_deeply( HealthCheck::Diagnostic::DBHCheck->new( dbh => $dbh )->check, {
    label  => 'dbh_check',
    status => 'OK',
    info   => "Successful SQLite read write check of $dbname as FakeUser",
}, "OK status as expected" );

# Turn it into a coderef that returns a disconnected dbh
$dbh = do { my $x = $dbh; sub { my $y = $x->(); $y->disconnect; $y } };

is_deeply( HealthCheck::Diagnostic::DBHCheck->check( dbh => $dbh ), {
    status => 'CRITICAL',
    info   => "Unsuccessful SQLite read write check of $dbname as FakeUser",
}, "CRITICAL status as expected" );

done_testing;
