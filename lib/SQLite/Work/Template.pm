package SQLite::Work::Template;
use strict;
use warnings;

=head1 NAME

SQLite::Work::Template - template stuff for SQLite::Work

=head1 VERSION

This describes version B<0.04> of SQLite::Work::Template.

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

    use SQLite::Work::Template;

    my $tobj = SQLite::Work::Template->new(%new_args);

    $out =~ s/{([^}]+)}/$tobj->fill_in(row_hash=>$row_hash,targ=>$1)/eg;

=head1 DESCRIPTION

This is the template stuff used for SQLite::Work templates
(for rows, headers and groups).

The format is as follows:

=over

=item {$colname}

A variable; will display the value of the column, or nothing if
that value is empty.

=item {?colname stuff [$colname] more stuff}

A conditional.  If the value of 'colname' is not empty, this will
display "stuff value-of-column more stuff"; otherwise it displays
nothing.

    {?col1 stuff [$col1] thing [$col2]}

This would use both the values of col1 and col2 if col1 is not
empty.

=item {?colname stuff [$colname] more stuff!!other stuff}

A conditional with "else".  If the value of 'colname' is not empty, this
will display "stuff value-of-column more stuff"; otherwise it displays
"other stuff".

This version can likewise use multiple columns in its display parts.

    {?col1 stuff [$col1] thing [$col2]!![$col3]}

=item {&funcname(arg1,...,argN)}

Call a function with the given args; the return value of the
function will be what is put in its place.

    {&MyPackage::myfunc(stuff,[$col1])}

This would call the function myfunc in the package MyPackage, with the
arguments "stuff", and the value of col1.  The package MyPackage should
be activated by using the 'use_package' argument in L<SQLite::Work>
(or in the L<sqlreport> script).

=back

=cut

=head1 CLASS METHODS

=head2 new

my $obj = SQLite::Work::Template->new();

Make a new template object.

=cut

sub new {
    my $class = shift;
    my %parameters = @_;
    my $self = bless ({%parameters}, ref ($class) || $class);

    return ($self);
} # new

=head1 METHODS

=head2 fill_in

Fill in the given value.

    $val = $obj->fill_in(targ=>$targ,
	row_hash=>$row_hashref,
	show_cols=>\%show_cols);

Where 'targ' is the target value, which is either a variable target,
or a conditional target.

The 'row_hash' is a hash containing names and values.

The 'show_cols' is a hash saying which of these "column names"
ought to be displayed, and which suppressed.

This can do templating by using the exec ability of substitution, for
example:

    $out =~ s/{([^}]+)}/$tobj->fill_in(row_hash=>$row_hash,targ=>$1)/eg;

=cut
sub fill_in {
    my $self = shift;
    my %args = (
	targ=>'',
	row_hash=>undef,
	show_cols=>undef,
	@_
    );
    my $targ = $args{targ};

    return '' if (!$targ);
    if ($targ =~ /^\$(\w+[:\w]*)$/)
    {
	my $val = $self->get_value(val_id=>$1,
	    row_hash=>$args{row_hash},
	    show_cols=>$args{show_cols});
	if (defined $val)
	{
	    return $val;
	}
	else # not a column -- return nothing
	{
	    return '';
	}
    }
    elsif ($targ =~ /^\?(\w+)\s(.*)!!(.*)$/)
    {
	my $val_id = $1;
	my $yes_t = $2;
	my $no_t = $3;
	my $val = $self->get_value(val_id=>$val_id,
	    row_hash=>$args{row_hash},
	    show_cols=>$args{show_cols});
	if ($val)
	{
	    $yes_t =~ s/\[(\$[^\]]+)\]/$self->fill_in(row_hash=>$args{row_hash},show_cols=>$args{show_cols},targ=>$1)/eg;
	    return $yes_t;
	}
	else # no value, return alternative
	{
	    $no_t =~ s/\[(\$[^\]]+)\]/$self->fill_in(row_hash=>$args{row_hash},show_cols=>$args{show_cols},targ=>$1)/eg;
	    return $no_t;
	}
    }
    elsif ($targ =~ /^\?(\w+)\s(.*)$/)
    {
	my $val_id = $1;
	my $yes_t = $2;
	my $val = $self->get_value(val_id=>$val_id,
	    row_hash=>$args{row_hash},
	    show_cols=>$args{show_cols});
	if ($val)
	{
	    $yes_t =~ s/\[(\$[^\]]+)\]/$self->fill_in(row_hash=>$args{row_hash},show_cols=>$args{show_cols},targ=>$1)/eg;
	    return $yes_t;
	}
	else # no value, return nothing
	{
	    return '';
	}
    }
    elsif ($targ =~ /^\&([\w:]+)\((.*)\)$/)
    {
	# function
	my $func_name = $1;
	my $fargs = $2;
	$fargs =~ s/\[(\$[^\]]+)\]/$self->fill_in(row_hash=>$args{row_hash},show_cols=>$args{show_cols},targ=>$1)/eg;
	{
	    no strict('refs');
	    return &{$func_name}(split(/,/,$fargs));
	}
    }
    return '';
} # fill_in

=head2 get_value

$val = $obj->get_value(val_id=>$val_id,
    row_hash=>$row_hashref,
    show_cols=>\%show_cols);

Get and format the given value.

=cut
sub get_value {
    my $self = shift;
    my %args = (
	val_id=>'',
	row_hash=>undef,
	show_cols=>undef,
	@_
    );
    my ($colname, @formats) = split(':', $args{val_id});

    my $value;
    if (exists $args{row_hash}->{$colname})
    {
	if (!$args{show_cols}
	    or $args{show_cols}->{$colname})
	{
	    $value = $args{row_hash}->{$colname};
	}
	else
	{
	    return '';
	}
    }
    else
    {
	return undef;
    }

    # we have a value to format
    foreach my $format (@formats) { 
	$value = $self->convert_value(value=>$value,
	    format=>$format,
	    name=>$colname); 
    }
    return $value;
} # get_value

=head2 convert_value

    my $val = $obj->convert_value(value=>$val,
	format=>$format,
	name=>$name);

Convert a value according to the given formatting directive.

Directives are:

=over

=item upper

Convert to upper case.

=item lower

Convert to lower case.

=item int

Convert to integer

=item float

Convert to float.

=item string

Return the value with no change.

=item truncateI<num>

Truncate to I<num> length.

=item dollars

Return as a dollar value (float of precision 2)

=item percent

Show as if the value is a percentage.

=item title

Put any trailing ,The or ,A at the front (as this is a title)

=item comma_front

Put anything after the last comma at the front (as with an author name)

=item month

Convert the number value to a month name.

=item nth

Convert the number value to a N-th value.

=item url

Convert to a HTML href link.

=item email

Convert to a HTML mailto link.

=item hmail

Convert to a "humanized" version of the email, with the @ and '.'
replaced with "at" and "dot"

=item html

Convert to simple HTML (simple formatting)

=item proper

Convert to a Proper Noun.

=item wordsI<num>

Give the first I<num> words of the value.

=item alpha

Convert to a string containing only alphanumeric characters
(useful for anchors or filenames)

=item namedalpha

Similar to 'alpha', but prepends the 'name' of the value.
Assumes that the name is only alphanumeric.

=back

=cut
sub convert_value {
    my $self = shift;
    my %args = @_;
    my $value = $args{value};
    my $style = $args{format};
    my $name = $args{name};

    $value ||= '';
    ($_=$style) || ($_ = 'string');
    SWITCH: {
	/^upper/i &&     (return uc($value));
	/^lower/i &&     (return lc($value));
	/^int/i &&       (return (defined $value ? int($value) : 0));
	/^float/i &&     (return (defined $value && sprintf('%f',($value || 0))) || '');
	/^string/i &&    (return $value);
	/^trunc(?:ate)?(\d+)/ && (return substr(($value||''), 0, $1));
	/^dollars/i &&
	    (return (defined $value && length($value)
		     && sprintf('%.2f',($value || 0)) || ''));
	/^percent/i &&
	    (return (($value<0.2) &&
		     sprintf('%.1f%%',($value*100))
		     || sprintf('%d%%',int($value*100))));
	/^url/i &&    (return "<a href='$value'>$value</a>");
	/^email/i &&    (return "<a mailto='$value'>$value</a>");
	/^hmail/i && do {
	    $value =~ s/@/ at /;
	    $value =~ s/\./ dot /g;
	    return $value;
	};
	/^html/i &&	 (return $self->simple_html($value));
	/^title/i && do {
	    $value =~ s/(.*)[,;]\s*(A|An|The)$/$2 $1/;
	    return $value;
	};
	/^comma_front/i && do {
	    $value =~ s/(.*)[,]([^,]+)$/$2 $1/;
	    return $value;
	};
	/^proper/i && do {
	    $value =~ s/(^w|\b\w)/uc($1)/eg;
	    return $value;
	};
	/^month/i && do {
	    return $value if !$value;
	    return ($value == 1
		    ? 'January'
		    : ($value == 2
		       ? 'February'
		       : ($value == 3
			  ? 'March'
			  : ($value == 4
			     ? 'April'
			     : ($value == 5
				? 'May'
				: ($value == 6
				   ? 'June'
				   : ($value == 7
				      ? 'July'
				      : ($value == 8
					 ? 'August'
					 : ($value == 9
					    ? 'September'
					    : ($value == 10
					       ? 'October'
					       : ($value == 11
						  ? 'November'
						  : ($value == 12
						     ? 'December'
						     : $value
						    )
						 )
					      )
					   )
					)
				     )
				  )
			       )
			    )
			  )
			  )
	    );
	};
	/^nth/i && do {
	    return $value if !$value;
	    return ($value =~ /1$/
		? "${value}st"
		: ($value =~ /2$/
		    ? "${value}nd"
		    : ($value =~ /3$/
			? "${value}rd"
			: "${value}th"
		    )
		)
	    );
	};
	/^alpha/i && do {
	    $value =~ s/[^a-zA-Z0-9]//g;
	    return $value;
	};
	/^namedalpha/i && do {
	    $value =~ s/[^a-zA-Z0-9]//g;
	    $value = join('', $name, '_', $value);
	    return $value;
	};
	/^words(\d+)/ && do {
	    my $ct = $1;
	    ($ct>0) || return '';
	    my @sentence = split(/\s+/, $value);
	    my (@words) = splice(@sentence,0,$ct);
	    return join(' ', @words);
	};

	# otherwise, give up
	return "  {{{ style $style not supported }}}  ";
    }
} # convert_value

=head2 simple_html

$val = $obj->simple_html($val);

Do a simple HTML conversion of the value.
bold, italic, <br>

=cut
sub simple_html {
    my $self = shift;
    my $value = shift;

    $value =~ s#\n[\s][\s][\s]+#<br/>\n&nbsp;&nbsp;&nbsp;&nbsp;#sg;
    $value =~ s#\s*\n\s*\n#<br/><br/>\n#sg;
    $value =~ s#\*([^*]+)\*#<i>$1</i>#sg;
    $value =~ s/\^([^^]+)\^/<b>$1<\/b>/sg;
    $value =~ s/\#([^#<>]+)\#/<b>$1<\/b>/sg;
    return $value;
} # simple_html

=head1 Callable Functions

=head2 safe_backtick

{&safe_backtick(myprog,arg1,arg2...argN)}

Return the results of a program, without risking evil shell calls.
This requires that the program and the arguments to that program
be given separately.

=cut
sub safe_backtick {
    my @prog_and_args = @_;
    my $progname = $prog_and_args[0];

    # if they didn't give us anything, return
    if (!$progname)
    {
	return '';
    }
    # call the program
    # do a fork and exec with an open;
    # this should preserve the environment and also be safe
    my $result = '';
    my $fh;
    my $pid = open($fh, "-|");
    if ($pid) # parent
    {
	{
	    # slurp up the result all at once
	    local $/ = undef;
	    $result = <$fh>;
	}
	close($fh) || warn "$progname program script exited $?";
    }
    else # child
    {
	# call the program
	# force exec to use an indirect object,
	# so that evil shell stuff will die, even
	# for a program with no arguments
	exec { $progname } @prog_and_args or die "$progname failed: $!\n";
	# NOTREACHED
    }
    return $result;
} # safe_backtick

=head1 REQUIRES

    Test::More

=head1 INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

In order to install somewhere other than the default, such as
in a directory under your home directory, like "/home/fred/perl"
go

   perl Build.PL --install_base /home/fred/perl

as the first step instead.

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the script.

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}


=head1 SEE ALSO

perl(1).
DBI
DBD::SQLite

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SQLite::Work
__END__
