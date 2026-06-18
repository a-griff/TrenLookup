<p align="center">
  <img src="TrenLookup.png" alt="TrenLookup logo" width="420">
</p>

# TrenLookup.pl

Interactive train route lookup utility for the Trenitalia / ViaggiaTreno backend.

TrenLookup allows you to search for stations using partial names, retrieve live departures, inspect train routes, and determine which trains travel between two selected stations.

Unlike simple departure boards, TrenLookup validates the actual train route and direction using station IDs, eliminating many false positives that occur when relying only on destination names.

---

## Features

* Interactive station search using `dialog`
* Partial station name matching
* Live departure retrieval
* Route verification using station IDs
* Direction-aware route validation
* Verbose debugging mode
* Single-file Perl script
* No API keys required

---

## Requirements

### Perl Modules

These modules are included with most Perl installations:

* strict
* warnings
* utf8
* POSIX
* Time::Local
* FindBin

### External Programs

* dialog
* curl
* jq

---

## Installation

### Slackware

```bash
slackpkg install curl jq dialog
```

### Debian / Ubuntu / Linux Mint

```bash
sudo apt install curl jq dialog
```

---

## Usage

Normal mode:

```bash
perl TrenLookup.pl
```

Verbose debugging mode:

```bash
perl TrenLookup.pl -v
```

---

## Example

The program will prompt for a departure station:

```text
Enter DEPARTURE station (e.g. 'Roma')
```

and then a destination station:

```text
Enter DESTINATION station (e.g. 'Mila')
```

After selecting stations from the menus, TrenLookup retrieves current departures and validates which trains actually travel from the selected departure station to the selected destination station.

Example:

```text
=======================================================
 ROUTE-CHECKED TRAINS
=======================================================
From : PISA/BINARI PISA S.ROSSORE (S06501)
To   : VIAREGGIO (S06040)
=======================================================

11:12 REG 18361 -> LA SPEZIA CENTRALE
  Stops at : VIAREGGIO (S06040)
  Delay    : 0m
  Platform : 2

11:39 REG 19342 -> MASSA CENTRO
  Stops at : VIAREGGIO (S06040)
  Delay    : 0m
  Platform : 1

11:57 REG 18444 -> BORGO VAL DI TARO
  Stops at : VIAREGGIO (S06040)
  Delay    : 0m
  Platform : 3
```

---

## How It Works

### 1. Station Resolution

The station search dialog uses the ViaggiaTreno autocomplete endpoint to convert station names into internal station IDs.

Example:

```text
VIAREGGIO -> S06040
```

### 2. Departure Retrieval

The script retrieves current departures from the selected origin station.

### 3. Route Verification

Each candidate train is checked using the train movement endpoint.

The script compares:

* Departure station ID
* Destination station ID
* Scheduled route order

A train is considered valid only when:

```text
Destination station occurs after departure station in the train route.
```

This prevents false positives caused by trains traveling in the opposite direction.

---

## Debugging

Verbose mode creates:

```text
~/.train_lookup_debug.txt
```

Run:

```bash
perl TrenLookup.pl -v
```

The log includes:

* API requests
* Station resolution results
* Route validation checks
* Route stop information
* Direction verification

---

## Configuration

The script contains two configuration sections near the top:

### User Settings

Used for normal customization:

```perl
my $DEBUG_FILE = "$ENV{HOME}/.train_lookup_debug.txt";
my $VERBOSE    = (@ARGV && $ARGV[0] eq '-v') ? 1 : 0;
my $CURL_TIMEOUT = 10;
```

### System Settings

Contains the ViaggiaTreno API endpoints.

These URLs may occasionally change if Trenitalia or RFI modifies the backend.

```perl
my $API_AUTOCOMPLETE = "...";
my $API_PARTENZE    = "...";
my $API_ANDAMENTO   = "...";
```

---

## Notes

This project uses publicly accessible ViaggiaTreno endpoints.

The ViaggiaTreno API is unofficial and undocumented. Endpoint formats and response structures may change without notice.

The API URLs have been isolated into a dedicated configuration section to simplify future maintenance.

---

## Disclaimer

This project is an independent utility and is not affiliated with, endorsed by, or supported by Trenitalia, RFI, or ViaggiaTreno.

All trademarks and service names belong to their respective owners.
