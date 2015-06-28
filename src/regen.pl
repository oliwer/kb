#!/usr/bin/env perl

#
# TODO:
#  - look at file timestamps to avoid rebuilding everything each time
#  - add a -f option to rebuild everything
#

use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use File::Copy;
use File::Spec::Functions;
use Pod::Simple::XHTML 3.28;

use constant {
	PUBDIR => '..',
	STYLE  => 'static/classy.css',
	INDEX  => '_index.html',
	TITLE_PREFIX => 'Knowledge Base',
};

# Globals
my %index;

sub new_psx {
	my $psx = Pod::Simple::XHTML->new;

	$psx->perldoc_url_prefix('https://metacpan.org/pod/');
	$psx->default_title('Untitled');
	$psx->html_doctype('<!DOCTYPE html>');
	$psx->html_header_tags('<meta charset="utf-8">
<link rel="stylesheet" href="'.STYLE.'" type="text/css">
<link rel="stylesheet" href="static/tomorrow-night-eighties.css">
<script src="static/highlight-8.6.min.js"></script>');
	$psx->html_footer('
<div id="footer">
	<a href="./" alt="Back to Index"><i>Back to Index</i></a>
</div>
<script>hljs.initHighlightingOnLoad();</script>
</body>
</html>');

	return $psx;
}

#
# Return all filenames not starting with a '.' or '_'
#
sub lsdir {
	opendir my $dh, shift;
	grep { !/^\./ && !/^_/ } readdir $dh;
}

#
# Simple slurp
#
sub slurp {
	my $filename = shift;

	open my $fh, '<', $filename;
	local $/;
	return <$fh>;
}

#
# Simple spurt
#
sub spurt {
	my ($text, $filename) = @_;

	open my $fh, '>', $filename;
	print $fh $text;
}

#
# Return the file extenstion if it is handled, or undef otherwise.
#
sub find_ext {
	my $filename = shift;

	my ($ext) = $filename =~ /\.([a-zA-Z0-9]+)$/;
	return undef unless $ext;

	# Is this a supported file format?
	if ($ext =~ /^txt|pod|html$/i) {
		return lc($ext);
	}

	return undef;
}

#
# Return a filename without its extention
#
sub remove_ext {
	my $filename = shift;
	$filename =~ s/(\.\w+)$//;
	return $filename;
}

#
# Handle .txt documents - we just copy them to PUBDIR
#
sub gen_txt {
	my $filename = shift;

	say " => $filename";

	copy $filename, catfile(PUBDIR, $filename) or
		die "could not copy '$filename' : $!\n";

	$index{remove_ext($filename)} = $filename;
}

#
# Handle .html documents - we just copy them to PUBDIR
#
sub gen_html { goto gen_txt }

#
# Handle POD documents with Pod::Simple. Generates html.
#
sub gen_pod {
	my $podfile = shift;

	say " => $podfile";

	my $psx = new_psx();

	$psx->output_string(\(my $output));

	my $pod = slurp($podfile);

	# We need to catch the title because Pod::Simple
	# does not make it available.
	my ($title) = $pod =~ /^=head1\s+(.*)$/m;
	if ($title) {
		$psx->force_title(TITLE_PREFIX.' / '.$title);
	}

	$psx->parse_string_document($pod);
	$psx->scream();

	my $htmlfile = remove_ext($podfile) . '.html';
	spurt($output, catfile(PUBDIR, $htmlfile));

	if ($title) {
		$index{$title} = $htmlfile;
	} else {
		$index{remove_ext($htmlfile)} = $htmlfile;
	}
}

#
# Build index.html from template
#
sub build_index {
	say "Building index.html";

	my $html = slurp(INDEX);

	my ($title, $style) = (TITLE_PREFIX, STYLE);
	$html =~ s/vvTITLEvv/$title/g;
	$html =~ s/vvSTYLEvv/$style/;

	my $index = "<ul>\n";
	for my $title (sort { lc($a) cmp lc($b) } keys %index) {
		$index .= "  <li><a href=\"$index{$title}\" title=\"$title\">$title</a></li>\n";
	}
	$index .= "</ul>\n";

	$html =~ s/vvINDEXvv/$index/;

	spurt($html, catfile(PUBDIR, 'index.html'));
}


#
# M A I N
#

chdir $FindBin::Bin;

say "Building all pages...";

for my $page (lsdir('.')) {
	my $ext = find_ext($page) or next;

	if ($ext eq 'txt') {
		gen_txt($page);
	}
	elsif ($ext eq 'pod') {
		gen_pod($page);
	}
	elsif ($ext eq 'html') {
		gen_html($page);
	}
	else {
		warn "$page : unsupported format '$ext'\n";
	}
}

build_index();

say "Done";
