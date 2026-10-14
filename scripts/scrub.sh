#!/usr/bin/env bash
# Scrub check: fails if any file contains a blocked term, an em dash or an en dash.
# Usage: scripts/scrub.sh <file>...   (no args = all staged files)
# Terms are read from the user-level skill folder, never from this repo.
set -euo pipefail

TERMS_FILE="${SCRUB_TERMS_FILE:-$HOME/.claude/skills/publish-extra/scrub-terms.txt}"
if [[ ! -f "$TERMS_FILE" ]]; then
  echo "scrub: terms file not found at $TERMS_FILE" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(git diff --cached --name-only --diff-filter=ACMR)
  set -- "${files[@]+"${files[@]}"}"
fi
[[ $# -eq 0 ]] && { echo "scrub: nothing to check"; exit 0; }

TERMS_FILE="$TERMS_FILE" perl -CSD -e '
  use strict; use warnings;
  open(my $tf, "<", $ENV{TERMS_FILE}) or die "cannot read terms\n";
  my @pats;
  while (my $t = <$tf>) {
    chomp $t; $t =~ s/^\s+|\s+$//g;
    next if $t eq "" || $t =~ /^#/;
    push @pats, [$t, qr/$t/i];
  }
  push @pats, ["em dash", qr/\x{2014}|&(?:m(?=dash;)dash|#8212|#x2014);/i];
  push @pats, ["en dash", qr/\x{2013}|&(?:n(?=dash;)dash|#8211|#x2013);/i];
  my $hits = 0;
  for my $file (@ARGV) {
    open(my $fh, "<:encoding(UTF-8)", $file) or die "cannot read $file\n";
    my $n = 0;
    while (my $line = <$fh>) {
      $n++;
      $line =~ s{base64,[A-Za-z0-9+/=]+}{base64,<stripped>}g;
      for my $p (@pats) {
        while ($line =~ /$p->[1]/g) {
          my ($s, $e) = ($-[0], $+[0]);
          my $from = $s > 40 ? $s - 40 : 0;
          my $ctx = substr($line, $from, ($e - $from) + 40);
          $ctx =~ s/\s+/ /g;
          printf "%s:%d  [%s]  ...%s...\n", $file, $n, $p->[0], $ctx;
          $hits++;
        }
      }
    }
  }
  if ($hits) { print "\nscrub: $hits hit(s). Fix them before committing.\n"; exit 1 }
  print "scrub: clean (" . scalar(@ARGV) . " file(s))\n";
' "$@"
