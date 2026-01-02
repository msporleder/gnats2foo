#!/usr/bin/env perl
use strict;
use warnings;
use JSON;

# Field-oriented GNATS parser
# Each section has its own parsing logic based on field structure

# GNATS fields that can change in audit trail
my $CHANGE_FIELDS = qr/State|Responsible|Class|Priority|Severity|Category/;

my @lines = <>;

# Section markers
my $body_start = 0;
my $audit_start = 0;
my $unformatted_start = 0;

for my $i (0 .. $#lines) {
    if (!$body_start && $lines[$i] =~ /^>Number:/) {
        $body_start = $i;
    }
    if ($lines[$i] =~ /^>Audit-Trail:/) {
        $audit_start = $i + 1;  # Skip the marker line
    }
    if ($lines[$i] =~ /^>Unformatted:/) {
        $unformatted_start = $i + 1;  # Skip the marker line
        last;
    }
}

# Parse email headers (field: value format with continuations)
sub parse_email_headers {
    my @header_lines = @_;
    my %headers;
    my $current = undef;

    for my $line (@header_lines) {
        chomp $line;
        if ($line =~ /^From /) {
            $headers{mail_from} = $line;
            $current = undef;
        } elsif ($line =~ /^([A-Z][A-Za-z-]+):\s*(.*)$/) {
            $current = normalize_key($1);
            $headers{$current} = $2;
        } elsif ($current && $line =~ /^\s+(.+)$/) {
            $headers{$current} .= " $1";
        }
    }
    return \%headers;
}

# Parse GNATS body fields (>Field: value format with multi-line values)
sub parse_gnats_fields {
    my @field_lines = @_;
    my %fields;
    my $current = undef;

    for my $line (@field_lines) {
        chomp $line;
        if ($line =~ /^>([\w-]+):\s*(.*)$/) {
            $current = normalize_key($1);
            $fields{$current} = $2;
        } elsif ($current) {
            # Multi-line continuation
            $fields{$current} .= "\n" if length($fields{$current});
            $fields{$current} .= $line;
        }
    }

    # Trim fields
    for my $key (keys %fields) {
        $fields{$key} =~ s/\s+$//;
    }

    return \%fields;
}

# Parse audit trail into structured entries
sub parse_audit_trail {
    my @audit_lines = @_;
    my @entries;
    my $current = undef;

    for my $line (@audit_lines) {
        chomp $line;

        if ($line =~ /^From:\s*(.+)$/) {
            push @entries, finish_entry($current) if $current;
            $current = { type => 'comment', from => $1, body => [] };

        } elsif ($line =~ /^($CHANGE_FIELDS)-Changed-From-To:\s*(.+?)\s*->\s*(.+)$/) {
            push @entries, finish_entry($current) if $current;
            $current = {
                type => 'change',
                field => normalize_key($1),
                from => $2,
                to => $3,
                metadata => {},
                body => []
            };

        } elsif ($current && $line =~ /^($CHANGE_FIELDS)-Changed-By:\s*(.+)$/) {
            $current->{metadata}{changed_by} = $2;

        } elsif ($current && $line =~ /^($CHANGE_FIELDS)-Changed-When:\s*(.+)$/) {
            $current->{metadata}{changed_when} = $2;

        } elsif ($current && $line =~ /^($CHANGE_FIELDS)-Changed-Why:\s*(.*)$/) {
            $current->{in_why} = 1;
            push @{$current->{body}}, $2 if $2;

        } elsif ($current && $line =~ /^(To|Cc|Subject|Date):\s*(.+)$/) {
            $current->{metadata}{lc($1)} = $2;

        } elsif ($current) {
            push @{$current->{body}}, $line;
        }
    }

    push @entries, finish_entry($current) if $current;
    return \@entries;
}

# Finish building an audit entry
sub finish_entry {
    my $entry = shift;
    return undef unless $entry;

    my $text = join("\n", @{$entry->{body}});
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    delete $entry->{body};
    delete $entry->{in_why};

    if ($entry->{type} eq 'change') {
        $entry->{why} = $text if $text;
        for my $k (keys %{$entry->{metadata}}) {
            $entry->{$k} = $entry->{metadata}{$k};
        }
        delete $entry->{metadata};
    } else {
        $entry->{text} = $text if $text;
        for my $k (keys %{$entry->{metadata}}) {
            $entry->{$k} = $entry->{metadata}{$k};
        }
        delete $entry->{metadata};
    }

    return $entry;
}

# Normalize field names
sub normalize_key {
    my $key = shift;
    $key = lc($key);
    $key =~ s/-/_/g;
    return $key;
}

# Parse each section
my $headers = parse_email_headers(@lines[0 .. $body_start - 1]);

# Determine body end (either at audit trail, unformatted, or end of file)
my $body_end = $audit_start ? $audit_start - 1 :
               $unformatted_start ? $unformatted_start - 1 :
               $#lines;
my $fields = parse_gnats_fields(@lines[$body_start .. $body_end]);

# Parse audit trail only if it exists
my $audit;
if ($audit_start) {
    my $audit_end = $unformatted_start ? $unformatted_start - 2 : $#lines;
    $audit = parse_audit_trail(@lines[$audit_start .. $audit_end]);
} else {
    $audit = [];
}

my $unformatted = '';
if ($unformatted_start) {
    $unformatted = join('', @lines[$unformatted_start .. $#lines]);
    $unformatted =~ s/^\s+//;
    $unformatted =~ s/\s+$//;
}

# Append unformatted to description if present
my $description = $fields->{description} || '';
if ($unformatted) {
    $description .= "\n\n" if $description;
    $description .= "--- Unformatted ---\n" . $unformatted;
}

# Extract useful email metadata (drop SMTP details)
my %email_meta;
for my $key (qw(from date reply_to subject message_id)) {
    $email_meta{$key} = $headers->{$key} if $headers->{$key};
}

# Build JSON output
my %ticket = (
    number => $fields->{number} || '',
    synopsis => $fields->{synopsis} || '',
    category => $fields->{category} || '',
    class => $fields->{class} || '',
    severity => $fields->{severity} || '',
    priority => $fields->{priority} || '',
    state => $fields->{state} || '',
    confidential => (($fields->{confidential} || '') eq 'yes') ? JSON::true : JSON::false,

    submitter_id => $fields->{submitter_id} || '',
    originator => $fields->{originator} || '',
    organization => $fields->{organization} || '',
    responsible => $fields->{responsible} || '',
    notify_list => $fields->{notify_list} || '',

    arrival_date => $fields->{arrival_date} || '',
    closed_date => $fields->{closed_date} || '',
    last_modified => $fields->{last_modified} || '',

    release => $fields->{release} || '',
    environment => $fields->{environment} || '',
    description => $description,
    how_to_repeat => $fields->{how_to_repeat} || '',
    fix => $fields->{fix} || '',
    release_note => $fields->{release_note} || '',

    audit_trail => $audit,
    email_meta => \%email_meta,
);

# Add keywords if present (rarely used but keep in schema)
if ($fields->{keywords} && $fields->{keywords} ne '') {
    $ticket{keywords} = $fields->{keywords};
}

my $json = JSON->new->pretty->canonical;
print $json->encode(\%ticket);
