#!/home/acme/bin/perl
use strict;
use warnings;
use lib 'lib';
use File::Find::Rule;
use Text::Roman;
use WebService::Solr;
use Term::ProgressBar::Simple;
use Path::Class;
use Panga;
use MP3::Tag;
use IPC::Run qw( run timeout );

my $panga = Panga->new;

my $root      = '/home/acme/Public/mp3/';
my @filenames = File::Find::Rule->new->file->in($root);

my $progress = Term::ProgressBar::Simple->new( scalar @filenames );

my $solr = WebService::Solr->new( undef, { autocommit => 0 } );

my @docs;
foreach my $filename (@filenames) {
    my $prefix = file($filename)->relative($root);

    my $hash = $panga->get($prefix);

    $hash->{type_s} = 'mp3';
    $hash->{bytes_i} ||= -s $filename;

    unless ( $hash->{title_s} ) {
        my $mp3 = MP3::Tag->new($filename);
        my ( $title, $track, $artist, $album, $comment, $year, $genre )
            = $mp3->autoinfo();
        $hash->{title_s}  = $title;
        $hash->{artist_s} = $artist;
        $hash->{album_s}  = $album;
    }

    unless ( $hash->{mime_type_s} ) {
        run [ 'file', '-ib', $filename ], \undef, \my $mime_type, undef,
            timeout(10)
            or die "$?";
        chomp $mime_type;
        $hash->{mime_type_s} = $mime_type if $mime_type;
        $progress->message($mime_type);
    }

    $panga->put( $prefix, $hash );
    $progress++;
}

$panga->commit;
