package CleanSite::Callback;
use strict;
use warnings;

sub init_app {
    require MT::FileMgr::Local;
    require MT::CMS::Entry;
    my $build_entry_preview = \&MT::CMS::Entry::_build_entry_preview;

    no warnings 'redefine';
    *MT::CMS::Entry::_build_entry_preview = sub {
        my ( $app, $entry ) = @_;

        # Save preview content temporarily without publish temporary file.
        no warnings 'redefine';
        local *MT::FileMgr::Local::put_data = sub {
            $app->request( 'preview_content', $_[1] );
        };

        $build_entry_preview->( $app, $entry );
    };
}

sub tmpl_out_preview_strip {
    my ( $cb, $app, $tmpl ) = @_;

    my $preview_content = $app->request('preview_content');
    return unless $preview_content;

    # http://www.tagindex.com/html5/embed/iframe_srcdoc.html
    $preview_content =~ s/&/&amp;/gs;
    $preview_content =~ s/"/&quot;/gs;

    # Insert preview content.
    # TODO: remove src attribute.
    my $after  = quotemeta('></iframe>');
    my $insert = ' srcdoc="' . $preview_content . '"';
    $$tmpl =~ s/($after)/$insert$1/;

    # Clear request cache just in case.
    $app->request( 'preview_content', undef );
}

sub fileinfo_post_remove {
    my ( $cb, $obj, $original ) = @_;

    return unless MT->config('DeleteFilesAtRebuild');

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new('Local');

    my $file_path = $obj->file_path;
    if ( $fmgr->exists($file_path) ) {
        $fmgr->delete($file_path);
    }
}

sub blog_post_remove {
    my ( $cb, $obj, $original ) = @_;

    return unless MT->config('DeleteFilesAtRebuild');

    require File::Path;
    File::Path::rmtree( $obj->site_path );
}

sub category_post_remove {
    my ( $cb, $obj, $original ) = @_;

    return unless MT->config('DeleteFilesAtRebuild');

    require File::Spec;
    my $category_path = File::Spec->catdir(
        MT->model('blog')->load( $obj->blog_id )->site_path,
        map { $_->basename } reverse( $obj, $obj->parent_categories ),
    );

    rmdir $category_path;
}

1;
