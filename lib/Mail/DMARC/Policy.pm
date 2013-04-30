package Mail::DMARC::Policy;
use strict;
use warnings;

=head1 NAME

Mail::DMARC::Policy

=head1 SYNOPSIS

A DMARC policy in object format

=head1 EXAMPLES

A DMARC record looks like this:

    v=DMARC1; p=reject; adkim=s; aspf=s; rua=mailto:dmarc@example.com; pct=100;

DMARC records are stored in TXT resource records in the DNS, at _dmarc.example.com. To retrieve a DMARC record for a domain, use a dig query like this:

    dig +short _dmarc.example.com TXT

Or in a more perlish fashion:

    my $res = Net::DNS::Resolver->new(dnsrch => 0);
    $res->send('_dmarc.example.com', 'TXT');


=head1 USAGE

 my $pol = Mail::DMARC::Policy->new(
    'v=DMARC1; p=none; rua=mailto:dmarc@example.com'
    );

 print "not a valid DMARC version!"    if $pol->v ne 'DMARC1';
 print "take no action"                if $pol->p eq 'none';
 print "reject that unaligned message" if $pol->p eq 'reject';
 print "do not send aggregate reports" if ! $pol->rua;
 print "do not send forensic reports"  if ! $pol->ruf;

=head1 METHODS

=cut

my %defaults = (
    adkim => 'r',
    aspf  => 'r',
    fo    => 0,
    ri    => 86400,
    rf    => 'afrf',
    pct   => 100,
        );

sub new {

=head2 new

Create a new empty policy:

   my $pol = Mail::DMARC::Policy->new;

Create a new policy from named arguments:

   my $pol = Mail::DMARC::Policy->new(
            v   => 'DMARC1',
            p   => 'none',
            pct => 50,
           );

Create a new policy from a DMARC DNS resource record:

   my $pol = Mail::DMARC::Policy->new(
            'v=DMARC1; p=reject; rua=mailto:dmarc@example.com; pct=50;'
           );

If a policy is passed in (the latter two examples), the resulting policy object will be populated with default values for any unspecified parameters. The p and v tags are required and have no default. The alignment specifiers adkim and aspf default to 'r' (relaxed) and will be populated if not present in the request.

=cut

    my $class = shift;
    my $package = ref $class ? ref $class : $class;
    my $self = bless {}, $package;

    return $self                 if 0 == @_;  # no arguments
    return $self->parse( shift ) if 1 == @_;  # a string to parse

    die "invalid arguments" if @_ && @_ % 2 != 0;
    my $policy = { %defaults, @_ };
    bless $policy, $package;
    die "invalid  policy" unless $self->is_valid( $policy );
    return bless $policy, $package;  # @_ values will override defaults
};

sub parse {

=head2 parse

Accepts a string containing a DMARC Resource Record, as it would be retrieved
via DNS.

    my $pol = Mail::DMARC::Policy->new;
    $pol->parse( 'v=DMARC1; p=none; rua=mailto:dmarc@example.com' );

=cut


    my $self = shift;
    die "invalid parse request" if 1 != scalar @_;
    my $str = shift;

    $str =~ s/\s//g;                         # remove all whitespace
    $str =~ s/\\;/;/;                        # replace \; with ;
    my %dmarc = map { split /=/, $_ } split /;/, $str;
    my $policy = { %defaults, %dmarc };
    die "invalid policy" if ! $self->is_valid( $policy );
    return bless $policy, ref $self;  # inherited defaults + overrides
}

=head1 Record Tags

The descriptions of each DMARC record tag and its corresponding values is from the March 31, 2013 draft of the DMARC spec:

  https://datatracker.ietf.org/doc/draft-kucherawy-dmarc-base/?include_text=1

Each tag has a mutator that's a setter and getter. To set any of the tag values, pass in the new value. Examples:

  $pol->p('none');                         set policy action to none
  print "do nothing" if $pol->p eq 'none'; get policy action

When new values are passed in, they are validated. Invalid values throw exceptions.

=cut

sub v {
    return $_[0]->{v} if 1 == scalar @_;
    die "invalid DMARC version" if 'DMARC1' ne $_[1];
    return $_[0]->{v} = $_[1];

=head2 v

Version (plain-text; REQUIRED).  Identifies the record retrieved
as a DMARC record.  It MUST have the value of "DMARC1".  The value
of this tag MUST match precisely; if it does not or it is absent,
the entire retrieved record MUST be ignored.  It MUST be the first
tag in the list.

=cut

};

sub p {
    return $_[0]->{p} if 1 == scalar @_;
    die "invalid p" unless $_[0]->is_valid_p($_[1]);
    return $_[0]->{p} = $_[1];

=head2 p

Requested Mail Receiver policy (plain-text; REQUIRED for policy
records).  Indicates the policy to be enacted by the Receiver at
the request of the Domain Owner.  Policy applies to the domain
queried and to sub-domains unless sub-domain policy is explicitly
described using the "sp" tag.  This tag is mandatory for policy
records only, but not for third-party reporting records (see
Section 8.2).

=cut

};

# sp=reject;   (subdomain policy: default, same as p)
sub sp {
    return $_[0]->{sp} if 1 == scalar @_;
    die "invalid sp" unless $_[0]->is_valid_p($_[1]);
    return $_[0]->{sp} = $_[1];

=head2 sp

{R6} Requested Mail Receiver policy for subdomains (plain-text;
OPTIONAL).  Indicates the policy to be enacted by the Receiver at
the request of the Domain Owner.  It applies only to subdomains of
the domain queried and not to the domain itself.  Its syntax is
identical to that of the "p" tag defined above.  If absent, the
policy specified by the "p" tag MUST be applied for subdomains.

=cut

};

sub adkim {
    return $_[0]->{adkim} if 1 == scalar @_;
    die "invalid adkim" unless grep {/^$_[1]$/} qw/ r s /;
    return $_[0]->{adkim} = $_[1];

=head2 adkim

(plain-text; OPTIONAL, default is "r".)  Indicates whether or
not strict DKIM identifier alignment is required by the Domain
Owner.  If and only if the value of the string is "s", strict mode
is in use.  See Section 4.3.1 for details.

=cut

};

sub aspf {
    return $_[0]->{aspf} if 1 == scalar @_;
    die "invalid aspf" unless grep {/^$_[1]$/} qw/ r s /;
    return $_[0]->{aspf} = $_[1];

=head2 aspf

(plain-text; OPTIONAL, default is "r".)  Indicates whether or
not strict SPF identifier alignment is required by the Domain
Owner.  If and only if the value of the string is "s", strict mode
is in use.  See Section 4.3.2 for details.

=cut

};

sub fo {
    return $_[0]->{fo} if 1 == scalar @_;
    die "invalid fo" unless grep {/^$_[1]$/} qw/ 0 1 d s /;
    return $_[0]->{fo} = $_[1];

=head2 fo

Failure reporting options (plain-text; OPTIONAL, default "0"))
Provides requested options for generation of failure reports.
Report generators MAY choose to adhere to the requested options.
This tag's content MUST be ignored if a "ruf" tag (below) is not
also specified.  The value of this tag is a colon-separated list
of characters that indicate failure reporting options as follows:

  0: Generate a DMARC failure report if all underlying
     authentication mechanisms failed to produce an aligned "pass"
     result.

  1: Generate a DMARC failure report if any underlying
     authentication mechanism failed to produce an aligned "pass"
     result.

  d: Generate a DKIM failure report if the message had a signature
     that failed evaluation, regardless of its alignment.  DKIM-
     specific reporting is described in [AFRF-DKIM].

  s: Generate an SPF failure report if the message failed SPF
     evaluation, regardless of its alignment. SPF-specific
     reporting is described in [AFRF-SPF].

=cut

};

sub rua {
    return $_[0]->{rua} if 1 == scalar @_;
    return $_[0]->{rua} = $_[1];

#TODO: validate as comma spaced list of URIs

=head2 rua

Addresses to which aggregate feedback is to be sent (comma-
separated plain-text list of DMARC URIs; OPTIONAL). {R11} A comma
or exclamation point that is part of such a DMARC URI MUST be
encoded per Section 2.1 of [URI] so as to distinguish it from the
list delimiter or an OPTIONAL size limit.  Section 8.2 discusses
considerations that apply when the domain name of a URI differs
from that of the domain advertising the policy.  See Section 15.6
for additional considerations.  Any valid URI can be specified.  A
Mail Receiver MUST implement support for a "mailto:" URI, i.e. the
ability to send a DMARC report via electronic mail.  If not
provided, Mail Receivers MUST NOT generate aggregate feedback
reports.  URIs not supported by Mail Receivers MUST be ignored.
The aggregate feedback report format is described in Section 8.3.

=cut

};


sub ruf {
    return $_[0]->{ruf} if 1 == scalar @_;
    return $_[0]->{ruf} = $_[1];

#TODO: validate as comma spaced list of URIs

=head2 ruf

Addresses to which message-specific failure information is to
be reported (comma-separated plain-text list of DMARC URIs;
OPTIONAL). {R11} If present, the Domain Owner is requesting Mail
Receivers to send detailed failure reports about messages that
fail the DMARC evaluation in specific ways (see the "fo" tag
above).  The format of the message to be generated MUST follow
that specified in the "rf" tag.  Section 8.2 discusses
considerations that apply when the domain name of a URI differs
from that of the domain advertising the policy.  A Mail Receiver
MUST implement support for a "mailto:" URI, i.e. the ability to
send a DMARC report via electronic mail.  If not provided, Mail
Receivers MUST NOT generate failure reports.  See Section 15.6 for
additional considerations.

=cut

};

sub rf {
    return $_[0]->{rf} if 1 == scalar @_;
    foreach my $f ( split /,/, $_[1] ) {
        die "invalid format: $f" if ! $_[0]->is_valid_rf( lc $f );
    }
    return $_[0]->{rf} = $_[1];

=head2 rf

Format to be used for message-specific failure reports (comma-
separated plain-text list of values; OPTIONAL; default "afrf").
The value of this tag is a list of one or more report formats as
requested by the Domain Owner to be used when a message fails both
[SPF] and [DKIM] tests to report details of the individual
failure.  The values MUST be present in the registry of reporting
formats defined in Section 14; a Mail Receiver observing a
different value SHOULD ignore it, or MAY ignore the entire DMARC
record.  Initial default values are "afrf" (defined in [AFRF]) and
"iodef" (defined in [IODEF]).  See Section 8.4 for details.

=cut

};

sub ri {
    return $_[0]->{ri} if 1 == scalar @_;
    die unless ($_[1] eq int($_[1]) && $_[1] >= 0 && $_[1] <= 4294967295);
    $_[0]->{ri} = $_[1];

=head2 ri

Interval requested between aggregate reports (plain-text, 32-bit
unsigned integer; OPTIONAL; default 86400). {R14} Indicates a
request to Receivers to generate aggregate reports separated by no
more than the requested number of seconds.  DMARC implementations
MUST be able to provide daily reports and SHOULD be able to
provide hourly reports when requested.  However, anything other
than a daily report is understood to be accommodated on a best-
effort basis.

=cut

};

sub pct {
    return $_[0]->{pct} if 1 == scalar @_;
    die unless ($_[1] eq int($_[1]) && $_[1] >= 0 && $_[1] <= 100 );
    return $_[0]->{pct} = $_[1];

=head2 pct

(plain-text integer between 0 and 100, inclusive; OPTIONAL;
default is 100). {R8} Percentage of messages from the DNS domain's
mail stream to which the DMARC mechanism is to be applied.
However, this MUST NOT be applied to the DMARC-generated reports,
all of which must be sent and received unhindered.  The purpose of
the "pct" tag is to allow Domain Owners to enact a slow rollout
enforcement of the DMARC mechanism.  The prospect of "all or
nothing" is recognized as preventing many organizations from
experimenting with strong authentication-based mechanisms.  See
Section 7.1 for details.

=cut

};

sub is_valid_rf {
    my ($self, $f) = @_;
    return (grep {/^$f$/} qw/ iodef rfrf /) ? 1 : 0;
};

sub is_valid_p {
    my ($self, $p) = @_;
    return (grep {/^$p$/} qw/ none reject quarantine /) ? 1 : 0;
};

sub is_valid {
    my ($self, $obj) = @_;
    die "missing version specifier" if ! $obj->{v};
    die "invalid version" if 'dmarc1' ne lc $obj->{v};
    die "missing policy action" if ! $obj->{p};
    die "invalid policy action" if ! $self->is_valid_p( $obj->{p} );
    return 1;
};

1;