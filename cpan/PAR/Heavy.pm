package PAR::Heavy;
$PAR::Heavy::VERSION = '0.12';

=head1 NAME

PAR::Heavy - PAR guts

=head1 SYNOPSIS

(internal use only)

=head1 DESCRIPTION

No user-serviceable parts inside.

=cut

########################################################################
# Dynamic inclusion of XS modules

my ($bootstrap, $dl_findfile);  # Caches for code references
my ($dlext);                    # Cache for $Config{dlext}
my ($cache_key);                # The current file to find
my $is_insensitive_fs = (
    -s $0
        and (-s lc($0) || -1) == (-s uc($0) || -1)
        and (-s lc($0) || -1) == -s $0
);

# Adds pre-hooks to Dynaloader's key methods
sub _init_dynaloader {
    return if $bootstrap;
    return unless eval { require DynaLoader; DynaLoader::dl_findfile(); 1 };

    $bootstrap   = \&DynaLoader::bootstrap;
    $dl_findfile = \&DynaLoader::dl_findfile;

    local $^W;
    *{'DynaLoader::dl_expandspec'}  = sub { return };
    *{'DynaLoader::bootstrap'}      = \&_bootstrap;
    *{'DynaLoader::dl_findfile'}    = \&_dl_findfile;
}

# Return the cached location of .dll inside PAR first, if possible.
sub _dl_findfile {
    return $FullCache{$cache_key} if exists $FullCache{$cache_key};
    if ($is_insensitive_fs) {
        # We have a case-insensitive filesystem...
        my ($key) = grep { lc($_) eq lc($cache_key) } keys %FullCache;
        return $FullCache{$key} if defined $key;
    }
    return $dl_findfile->(@_);
}

# Find and extract .dll from PAR files for a given dynamic module.
sub _bootstrap {
    my (@args) = @_;
    my ($module) = $args[0] or return;

    my @modparts = split(/::/, $module);
    my $modfname = $modparts[-1];

    $modfname = &DynaLoader::mod2fname(\@modparts)
        if defined &DynaLoader::mod2fname;

    if (($^O eq 'NetWare') && (length($modfname) > 8)) {
        $modfname = substr($modfname, 0, 8);
    }

    # XXX: Multi-platform .dll support in PARs needs better than $Config.
    # FIXME: Config is always loaded by PAR.pm!
    $dlext ||= do {
        require Config;
        (%Config::Config) ? $Config::Config{dlext} : '';
    };

    my $modpname = join((($^O eq 'MacOS') ? ':' : '/'), @modparts);
    my $file = $cache_key = "auto/$modpname/$modfname.$dlext";

    if ($FullCache{$file}) {
        # TODO: understand
        local $DynaLoader::do_expand = 1;
        return $bootstrap->(@args);
    }

    my $member;
    # First, try to find things in the peferentially loaded PARs:
    $member = PAR::_find_par_internals([@PAR::PAR_INC], undef, $file, 1)
      if defined &PAR::_find_par_internals;

    # If that failed to find the dll, let DynaLoader (try or) throw an error
    unless ($member) { 
        my $filename = eval { $bootstrap->(@args) };
        return $filename if not $@ and defined $filename;

        # Now try the fallback pars
        $member = PAR::_find_par_internals([@PAR::PAR_INC_LAST], undef, $file, 1)
          if defined &PAR::_find_par_internals;

        # If that fails, let dynaloader have another go JUST to throw an error
        # While this may seem wasteful, nothing really matters once we fail to
        # load shared libraries!
        unless ($member) { 
            return $bootstrap->(@args);
        }
    }

    $FullCache{$file} = _dl_extract($member, $file);

    # Now extract all associated shared objs in the same auto/ dir
    # XXX: shouldn't this also set $FullCache{...} for those files?
    my $first = $member->fileName;
    my $path_pattern = $first;
    $path_pattern =~ s{[^/]*$}{};
    if ($PAR::LastAccessedPAR) {
        foreach my $member ( $PAR::LastAccessedPAR->members ) {
            next if $member->isDirectory;

            my $name = $member->fileName;
            next if $name eq $first;
            next unless $name =~ m{^/?\Q$path_pattern\E\/[^/]*\.\Q$dlext\E[^/]*$};
            $name =~ s{.*/}{};
            _dl_extract($member, $file, $name);
        }
    }

    local $DynaLoader::do_expand = 1;
    return $bootstrap->(@args);
}

sub _dl_extract {
    my ($member, $file, $name) = @_;

    require File::Spec;
    require File::Temp;

    my ($fh, $filename);

    # fix borked tempdir from earlier versions
    if ($ENV{PAR_TEMP} and -e $ENV{PAR_TEMP} and !-d $ENV{PAR_TEMP}) {
        unlink($ENV{PAR_TEMP});
        mkdir($ENV{PAR_TEMP}, 0755);
    }

    if ($ENV{PAR_CLEAN} and !$name) {
        ($fh, $filename) = File::Temp::tempfile(
            DIR         => ($ENV{PAR_TEMP} || File::Spec->tmpdir),
            SUFFIX      => ".$dlext",
            UNLINK      => ($^O ne 'MSWin32' and $^O !~ /hpux/),
        );
        ($filename) = $filename =~ /^([\x20-\xff]+)$/;
    }
    else {
        $filename = File::Spec->catfile(
            ($ENV{PAR_TEMP} || File::Spec->tmpdir),
            ($name || ($member->crc32String . ".$dlext"))
        );
        ($filename) = $filename =~ /^([\x20-\xff]+)$/;

        open $fh, '>', $filename or die $!
            unless -r $filename and -e _
                and -s _ == $member->uncompressedSize;
    }

    if ($fh) {
        binmode($fh);
        $member->extractToFileHandle($fh);
        close $fh;
        chmod 0755, $filename;
    }

    return $filename;
}

1;

=head1 SEE ALSO

L<PAR>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

L<http://par.perl.org/> is the official PAR website.  You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2002-2010 by Audrey Tang
E<lt>cpan@audreyt.orgE<gt>.

Copyright 2006-2010 by Steffen Mueller
E<lt>smueller@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
