#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Time::Local;
use FindBin;

# ==============================================================================
# TrenLookup.pl
# ==============================================================================
#
# DESCRIPTION:
#   Interactive RFI / TrenItalia train lookup using dialog.
#
#   1. Prompts for a departure station.
#   2. Prompts for an arrival station.
#   3. Resolves both station names to internal station IDs.
#   4. Retrieves live departures from the selected departure station.
#   5. Checks each train route using station IDs only.
#   6. Displays trains where ARR_ID occurs after DEP_ID in the route.
#
# DEPENDENCIES:
#   Perl core modules:
#     strict
#     warnings
#     utf8
#     POSIX
#     Time::Local
#     FindBin
#
#   External programs:
#     dialog
#     curl
#     jq
#
# Slackware install:
#   slackpkg install curl jq dialog
#
# Debian / Ubuntu / Mint install:
#   sudo apt install curl jq dialog
#
# ==============================================================================


# ==============================================================================
# USER SETTINGS
# ==============================================================================

my $DEBUG_FILE = "$ENV{HOME}/.train_lookup_debug.txt";
my $VERBOSE    = (@ARGV && $ARGV[0] eq '-v') ? 1 : 0;

my $CURL_TIMEOUT = 10;


# ==============================================================================
# SYSTEM SETTINGS - API ENDPOINTS
# ==============================================================================
#
# These may change if Trenitalia / RFI changes the ViaggiaTreno backend.
#
# ==============================================================================

my $API_AUTOCOMPLETE =
    "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/autocompletaStazione/%s";

my $API_PARTENZE =
    "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/partenze/%s/%s";

my $API_ANDAMENTO =
    "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/andamentoTreno/%s/%s/%s";


# ==============================================================================
# REQUIREMENTS CHECK
# ==============================================================================

foreach my $cmd (qw(dialog curl jq)) {
    if (system("command -v $cmd >/dev/null 2>&1") != 0) {
        die "Error: '$cmd' is missing.\n";
    }
}


# ==============================================================================
# HELPERS
# ==============================================================================

sub log_debug {
    my ($msg) = @_;
    return unless $VERBOSE;

    open(my $fh, '>>', $DEBUG_FILE) or return;
    print $fh "[" . strftime("%H:%M:%S", localtime) . "] $msg\n";
    close($fh);
}

sub url_encode {
    my ($s) = @_;
    $s =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord($1))/eg;
    return $s;
}

sub fetch_url {
    my ($url) = @_;

    log_debug("FETCH: $url");

    my $cmd =
        "curl -sS --compressed " .
        "--connect-timeout $CURL_TIMEOUT " .
        "--max-time $CURL_TIMEOUT " .
        "-H 'User-Agent: Mozilla/5.0' " .
        "-H 'Accept: application/json,text/plain,*/*' " .
        "-H 'Referer: http://www.viaggiatreno.it/infomobilita/index.jsp' " .
        "-H 'Origin: http://www.viaggiatreno.it' " .
        "'$url'";

    my $data = `$cmd 2>/tmp/trenlookup_curl_$$.err`;

    return $data;
}

sub terminate_and_clean {
    my ($reason) = @_;

    system("clear");
    print "Operation cancelled by user";
    print ": $reason" if $reason;
    print "\n";

    exit(1);
}


# ==============================================================================
# STATION LOOKUP WIZARD
# ==============================================================================

sub interactive_station_wizard {
    my ($prompt) = @_;

    my $selected_id   = "";
    my $selected_name = "";

    while (!$selected_id) {
        my $search_term = `dialog --stdout --title "Station Search" --inputbox "$prompt:" 8 60`;

        if ($? != 0 || !$search_term) {
            terminate_and_clean("User exited input screen.");
        }

        $search_term =~ s/^\s+|\s+$//g;

        log_debug("[LOOKUP] User searched for: $search_term");

        my $url = sprintf($API_AUTOCOMPLETE, url_encode($search_term));
        my $content = fetch_url($url);

        if (!$content || $content =~ /^\s*$/) {
            system("dialog --title 'Error' --msgbox 'No station data returned.' 7 60");
            next;
        }

        $content =~ tr/\r//d;

        my @lines = split(/\n/, $content);
        my @dialog_args;
        my %station_map;

        foreach my $line (@lines) {
            next if $line =~ /^\s*$/;

            if ($line =~ /^([^|]+)\|([^|]+)$/) {
                my $name = $1;
                my $code = $2;

                $name =~ s/^\s+|\s+$//g;
                $code =~ s/^\s+|\s+$//g;

                push @dialog_args, $code;
                push @dialog_args, $name;

                $station_map{$code} = $name;
            }
        }

        if (!@dialog_args) {
            system("dialog --title 'No Matches' --msgbox 'No stations matched \"$search_term\".' 7 60");
            next;
        }

        my $menu_cmd = sprintf(
            "dialog --stdout --title 'Select Station' --menu 'Choose exact station:' 15 70 7 %s",
            join(' ', map { "'$_'" } @dialog_args)
        );

        $selected_id = `$menu_cmd`;

        if ($? != 0) {
            $selected_id = "";
            next;
        }

        $selected_id =~ s/\s+$//;
        $selected_name = $station_map{$selected_id};
    }

    return ($selected_id, $selected_name);
}


# ==============================================================================
# DATE SETUP
# ==============================================================================

sub build_date_values {
    my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mons = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @t = localtime();

    my $tz = strftime("%z", localtime);

    my $date_string = sprintf(
        "%s %s %02d %04d %02d:%02d:%02d GMT%s",
        $days[$t[6]],
        $mons[$t[4]],
        $t[3],
        $t[5] + 1900,
        $t[2],
        $t[1],
        $t[0],
        $tz
    );

    my $midnight_epoch = timelocal(0, 0, 0, $t[3], $t[4], $t[5]);
    my $midnight_ms    = $midnight_epoch * 1000;

    return ($date_string, $midnight_ms);
}


# ==============================================================================
# MAIN
# ==============================================================================

my ($dep_id, $dep_name) =
    interactive_station_wizard("Enter DEPARTURE station (e.g. 'Roma')");

my ($arr_id, $arr_name) =
    interactive_station_wizard("Enter DESTINATION station (e.g. 'Mila')");

system("clear");

print "=======================================================\n";
print " STATION CONFIGURATION SUCCESSFULLY ACQUIRED\n";
print "=======================================================\n";
print "Departure Locked : $dep_name ($dep_id)\n";
print "Arrival Locked   : $arr_name ($arr_id)\n";
print "=======================================================\n";
print "Launching departure board analysis...\n";

sleep(1);

my ($date_string, $midnight_ms) = build_date_values();

my $partenze_url = sprintf(
    $API_PARTENZE,
    $dep_id,
    url_encode($date_string)
);

my $json = fetch_url($partenze_url);

die "No response from departures API.\n" if !$json || $json =~ /^\s*$/;

if ($json !~ /^\s*[\[\{]/) {
    log_debug("Non-JSON departures response: $json");
    die "Departures API returned non-JSON data. Run with -v for debug.\n";
}

die "Departures API returned an empty list for $dep_name ($dep_id).\n"
    if $json =~ /^\s*\[\s*\]\s*$/;

my $dep_tmp = "/tmp/trenlookup_departures_$$.json";

open(my $out, '>', $dep_tmp) or die "Cannot write $dep_tmp: $!\n";
print $out $json;
close($out);

my $jq_departures = qq{
jq -r '
.[] |
[
  (.categoria // ""),
  (.numeroTreno // ""),
  (.codOrigine // .idOrigine // ""),
  (.origine // ""),
  (.destinazione // ""),
  (.orarioPartenza // .orarioPartenzaZero // ""),
  (.ritardo // "0"),
  (.binarioProgrammatoPartenzaDescrizione // .binarioEffettivoPartenzaDescrizione // "-")
] | \@tsv
' "$dep_tmp"
};

my @departures = `$jq_departures 2>/dev/null`;

unlink($dep_tmp);

die "JSON received, but no departures could be parsed.\n" if !@departures;

print "\n";
print "=======================================================\n";
print " ROUTE-CHECKED TRAINS\n";
print "=======================================================\n";
print "From : $dep_name ($dep_id)\n";
print "To   : $arr_name ($arr_id)\n";
print "=======================================================\n";

my $found = 0;

foreach my $row (@departures) {
    chomp($row);

    my ($cat, $num, $cod_origine, $origin_name, $final_dest, $board_time, $delay, $platform) =
        split(/\t/, $row);

    next if !$num;
    next if !$cod_origine;

    my $andamento_url = sprintf(
        $API_ANDAMENTO,
        $cod_origine,
        $num,
        $midnight_ms
    );

    my $route_json = fetch_url($andamento_url);

    next if !$route_json || $route_json =~ /^\s*$/;
    next if $route_json !~ /^\s*[\[\{]/;

    my $route_tmp = "/tmp/trenlookup_route_${$}_${num}.json";

    open(my $rfh, '>', $route_tmp) or next;
    print $rfh $route_json;
    close($rfh);

    my $check_cmd = qq{
jq -r \\
  --arg DEP "$dep_id" \\
  --arg ARR "$arr_id" '
def stopid:
  (.id // .idStazione // .codiceStazione // "");

def stoptime:
  (
    .partenza_teorica //
    .arrivo_teorico //
    .programmata //
    .effettiva //
    .programmataZero //
    .arrivoReale //
    .partenzaReale //
    empty
  );

[
  .fermate[]? |
  {
    id: stopid,
    time: stoptime
  }
] as \$stops
|
(\$stops | map(select(.id == \$DEP)) | first) as \$depstop
|
(\$stops | map(select(.id == \$ARR)) | first) as \$arrstop
|
if (\$depstop == null or \$arrstop == null) then
  "NO_MATCH"
elif ((\$arrstop.time | tonumber) > (\$depstop.time | tonumber)) then
  "VALID\t" + (\$depstop.time | tostring) + "\t" + (\$arrstop.time | tostring)
else
  "WRONG_DIRECTION\t" + (\$depstop.time | tostring) + "\t" + (\$arrstop.time | tostring)
end
' "$route_tmp" 2>/dev/null
};

    my $check = `$check_cmd`;
    chomp($check);

    if ($VERBOSE) {
        my $debug_cmd = qq{
jq -r '
.fermate[]? |
[
  (.id // .idStazione // .codiceStazione // ""),
  (.stazione // ""),
  (.partenza_teorica // .arrivo_teorico // .programmata // .effettiva // .programmataZero // .arrivoReale // .partenzaReale // "")
] | \@tsv
' "$route_tmp" 2>/dev/null
};

        my @stops = `$debug_cmd`;

        log_debug("[ROUTE] TRAIN $num / codOrigine=$cod_origine / final=$final_dest");

        foreach my $s (@stops) {
            chomp($s);
            log_debug("[ROUTE]   STOP: $s");
        }

        log_debug("[ROUTE]   RESULT: $check");
    }

    unlink($route_tmp);

    next if $check !~ /^VALID\t/;

    my ($status, $dep_stop_time, $arr_stop_time) = split(/\t/, $check);

    $found++;

    my $display_time = $board_time;

    if ($display_time && $display_time =~ /^\d+$/ && $display_time > 1000000000000) {
        $display_time = strftime("%H:%M", localtime(int($display_time / 1000)));
    }

    my $arr_display = $arr_stop_time;

    if ($arr_display && $arr_display =~ /^\d+$/ && $arr_display > 1000000000000) {
        $arr_display = strftime("%H:%M", localtime(int($arr_display / 1000)));
    }

    $cat         ||= "-";
    $origin_name ||= "-";
    $final_dest  ||= "-";
    $delay       ||= "0";
    $platform    ||= "-";

    print "$display_time  $cat $num  -> $final_dest\n";
    print "  Origin   : $origin_name ($cod_origine)\n";
    print "  Stops at : $arr_name ($arr_id)";
    print " at $arr_display" if $arr_display;
    print "\n";
    print "  Delay    : ${delay}m\n";
    print "  Platform : $platform\n";
    print "\n";
}

if (!$found) {
    print "No forward route-checked trains found from $dep_name to $arr_name.\n";
    print "\n";
    print "Run this for debugging:\n";
    print "  perl TrenLookup.pl -v\n";
    print "\n";
    print "Then check:\n";
    print "  $DEBUG_FILE\n";
}

print "=======================================================\n";
