package CleanSite::Callback;
use strict;
use warnings;

sub init_app {
    require MT::FileMgr::Local;
    require MT::App;
    my $redirect = \&MT::App::redirect;
    require MT::CMS::Entry;
    my $build_entry_preview = \&MT::CMS::Entry::_build_entry_preview;
    require MT::CMS::Template;
    my $preview = \&MT::CMS::Template::preview;

    # Save preview content temporarily without publish temporary file.
    no warnings 'redefine';

    *MT::CMS::Entry::_build_entry_preview = sub {
        my ( $app, $entry ) = @_;

        no warnings 'redefine';
        local *MT::App::redirect = sub {
            $_[0]->request('entry_preview_content') || $redirect->(@_);
        };
        local *MT::FileMgr::Local::put_data = sub {
            $app->request( 'entry_preview_content', $_[1] );
        };

        $build_entry_preview->( $app, $entry );
    };

    *MT::CMS::Template::preview = sub {
        my $app = shift;

        no warnings 'redefine';
        local *MT::App::redirect = sub {
            $_[0]->request('tmpl_preview_content') || $redirect->(@_);
        };
        local *MT::FileMgr::Local::put_data = sub {
            $app->request( 'tmpl_preview_content', $_[1] );
        };

        $preview->($app);
    };
}

sub replace_iframe_tag {
    my ( $cb, $app, $tmpl ) = @_;

    my $before = quotemeta <<'__BEFORE__';
<iframe id="frame" frameborder="0" scrolling="auto" src="<$mt:var name="preview_url"$>?<mt:date format="%H%M%S">" onclick="return TC.stopEvent(event);"></iframe>
__BEFORE__

    my $after = <<'__AFTER__';
<iframe id="frame" frameborder="0" scrolling="auto" onclick="return TC.stopEvent(event);"></iframe>
__AFTER__

    $$tmpl =~ s/$before/$after/;
}

sub tmpl_out_preview_strip {
    my ( $cb, $app, $tmpl ) = @_;
    _insert_preview_content( $app, $tmpl, 'entry_preview_content' );
}

sub tmpl_out_preview_tmpl_strip {
    my ( $cb, $app, $tmpl ) = @_;
    _insert_preview_content( $app, $tmpl, 'tmpl_preview_content' );
}

sub _insert_preview_content {
    my ( $app, $tmpl, $cache_key ) = @_;

    my $preview_content = $app->request($cache_key);
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
    $app->request( $cache_key, undef );
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

    return 1;
}

sub remove_old_blog {
    my ( $cb, $obj, $original ) = @_;

    if ( !MT->config('DeleteFilesAtRebuild') || !MT->component('MoveAssets') )
    {
        return 1;
    }

    require File::Path;

    if ( $obj->site_path ne $original->site_path ) {
        File::Path::rmtree( $original->site_path );
    }

    if ( $obj->archive_path ne $original->archive_path ) {
        File::Path::rmtree( $original->archive_path );
    }

    return 1;
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
