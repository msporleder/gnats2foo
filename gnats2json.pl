#!/usr/pkg/bin/perl
use JSON;
use Data::Dumper;

my $txt;
my %p, %h;
my $infield = "Header"; #email headers, first field
#split the file into header, info, audit-trail, state-changes, unformatted
my @header, @info, @audit, @state, @unformatted;
@lines = <>; #oh well
#if ($lines[0] =~ m#^From #) { shift @lines; } #discard this line

while ( my $l = shift @lines ) {
  if ($l =~ m#^>Number:#) {
    unshift @lines, $l;
    last;
  } else {
    chomp $l;
    push @header, $l;
  }
}

#@header = grep { ! s/^$//g } @headerOrig;
while ( my $l = shift @lines ) {
  if ($l =~ m#^>Audit-Trail:#) {
    unshift @lines, $l;
    last;
  } else {
    chomp $l;
    push @body, $l;
  }
}

while ( my $l = shift @lines ) {
  if ($l =~ m#^>Unformatted:#) {
    unshift @lines, $l;
    last;
  } else {
    chomp $l;
    push @audit, $l;
  }
}

while ( my $l = shift @lines ) {
  chomp $l;
  push @unformatted, $l;
}

my $in = "";
foreach my $l (@header) {
  chomp $l;
  if ($l =~ m#^(.+):\s+(.+)$#) {
    $in = $1;
    $h{$in} = $2;
  } elsif ( $l =~ m#^From .+$#) {
    $h{"mailaudit"} = $l;
  } else {
    $h{$in} .= "$l\n";
  }
}
chomp %h;
$in = ""; foreach my $l (@body) {
  chomp $l;
  if ($l =~ m#^(>[A-Z].+?):\s*(.*$)#) {
    $in = $1;
    $b{$in} = $2;
  } else {
    $b{$in} .= "$l\n";
  }
}
chomp %b;

$in = "";
my @audittrail;
shift @audit; #throw away '>Audit-Trail:'
foreach my $l (@audit) {
  chomp $l;
  if ($l =~ m#^From: #) {
    push @audittrail, $l;
    $in = $#audittrail;
  } elsif ($l =~ m#^(?:State|Responsible)-Changed-From-To#) {
    push @audittrail, $l;
    $in = $#audittrail;
  } else {
    $audittrail[$in] .= $l;
  }
}

#print Dumper \%p;
#my %{$p{Number}} => %p;
#push(@j, \%p);
#my $json = to_json( \@j, {pretty => 1} );
#my $cmd = "curl -vvv localhost:8983/solr/update/json -H 'Content-type:application/json' -d \'$json\'";
#print "$cmd\n";
#qx#"$cmd"#;
#print "$json";
#print Dumper \@audit;
print Dumper \%h;
print Dumper \%b;
print Dumper \@audittrail;
