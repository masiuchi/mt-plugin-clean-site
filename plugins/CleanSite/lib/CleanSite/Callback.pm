package CleanSite::Callback;
use strict;
use warnings;

sub fileinfo_post_remove {
    my ( $cb, $obj, $original ) = @_;

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new('Local');

    my $file_path = $obj->file_path;
    if ( $fmgr->exists($file_path) ) {
        $fmgr->delete($file_path);
    }
}

sub blog_post_remove {
    my ( $cb, $obj, $original ) = @_;

    require File::Path;
    File::Path::rmtree( $obj->site_path );
}

sub category_post_remove {
    my ( $cb, $obj, $original ) = @_;

    require File::Spec;
    my $category_path = File::Spec->catdir(
        MT->model('blog')->load( $obj->blog_id )->site_path,
        map { $_->basename } reverse( $obj, $obj->parent_categories ),
    );

    rmdir $category_path;
}

1;
