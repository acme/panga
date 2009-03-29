package Panga;
use Moose;
use DBI;

has 'solr' => (
    is      => 'ro',
    isa     => 'WebService::Solr',
    default => sub {
        return WebService::Solr->new( undef, { autocommit => 0 } );
    }
);

has 'dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    default => sub {
        my $self     = shift;
        my $filename = 'panga.db';
        my $exists   = -f $filename;
        my $dbh      = DBI->connect(
            "dbi:SQLite:dbname=$filename",
            "", "",
            {   RaiseError => 1,
                AutoCommit => 0,
            }
        );

        unless ($exists) {
            $dbh->do('PRAGMA auto_vacuum = 1');
            $dbh->do( '
CREATE TABLE archive (
  guid varchar NOT NULL,
  meta varchar NOT NULL,
  PRIMARY KEY (guid)
)' );
        }
        return $dbh;
    },
);

sub get {
    my ( $self, $guid ) = @_;
    my $sth = $self->dbh->prepare('SELECT meta FROM archive WHERE guid = ?');
    $sth->execute($guid);
    $sth->bind_columns( \my $json );
    $sth->fetch;

    #    if ( $self->compressed ) {
    #     $json    = uncompress($json);
    #     $content = uncompress($content);
    #    }
    return {} unless $json;
    my $meta = JSON::XS->new->decode($json);
    return $meta;
}

sub put {
    my ( $self, $guid, $meta ) = @_;
    my $json = JSON::XS->new->encode($meta);

    #    if ( $self->compressed ) {
    #        $json    = compress($json);
    #        $content = compress($content);
    #    }

    my $sth = $self->dbh->prepare('REPLACE INTO archive VALUES (?, ?)');
    $sth->execute( $guid, $json );

    my $doc = WebService::Solr::Document->new;
    $doc->add_fields(
        guid => $guid,
        %$meta,
    );
    $self->solr->add($doc);
}

sub commit {
    my $self = shift;
    $self->dbh->commit;
    $self->solr->commit;
    $self->solr->optimize;
}

sub DESTROY {
    my $self = shift;
    $self->dbh->disconnect;
}

1;
