<p align="center">
  <img src="TrenLookup.png" alt="TrenLookup logo" width="420">
</p>

# TrenLookup

Interactive train route lookup utility for the Trenitalia / ViaggiaTreno backend.

TrenLookup allows you to search for stations using partial names, retrieve live departures, inspect train routes, and determine which trains travel directly between two selected stations.

Unlike simple departure boards, TrenLookup validates the actual train route and direction using station IDs, eliminating many false positives that occur when relying only on destination names.

TrenLookup is designed to answer a single question:

> Which train should I board at this station to reach my next station?

The program searches the live Trenitalia / ViaggiaTreno backend and displays the next available trains that travel between the selected departure and destination stations, including train number, destination, delay information, and platform assignment.

This utility works only for a single travel leg. Both the departure and destination stations must be stops on the same physical train. TrenLookup does not calculate journeys requiring train changes, does not search for connecting services, and does not provide route planning or itinerary generation.

Train numbers are often omitted from regional tickets and departure boards typically display only the train's final destination. As a result, it can be difficult to determine whether a particular train serves an intermediate station. TrenLookup solves this problem by validating the train's actual route and confirming that the destination station appears later in the train's stop sequence.

All information is obtained from live operational data. Train delays, platform assignments, routing information, and service availability may change at any time. Results represent the most accurate information available at the moment the query is performed.

---

## Features

* Interactive station search using `dialog`
* Partial station name matching
* Live departure retrieval
* Route verification using station IDs
* Direction-aware route validation
* Train number display
* Platform information display
* Delay information display
* Live route inspection
* Verbose debugging mode
* Single-file Perl implementation (*NIX version)
* Self-contained Android application
* No API keys required

---

## Requirements - Android

None. The Android APK is completely self-contained.

---

## Requirements - *NIX

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

## Files

### *NIX Version

`TrenLookup.pl`

Interactive Perl implementation for Linux and other Unix-like operating systems.

### Android Version

`trenlookup-2_0.apk`

Self-contained Android application.

---

## Installation

### Android

Install the APK normally through Android.

You may need to enable installation from unknown sources depending on your Android version.

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

The program first prompts for a departure station:

```text
Enter DEPARTURE station (e.g. 'Roma')
```

and then a destination station:

```text
Enter DESTINATION station (e.g. 'Mila')
```

After selecting stations from the menus, TrenLookup retrieves current departures and validates which trains actually travel from the selected departure station to the selected destination station.

Example output:

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

## What TrenLookup Does

TrenLookup identifies trains that travel directly between two selected stations.

For example:

```text
Pisa S. Rossore
        |
        |
        v
Viareggio
```

The program checks every candidate train and confirms that:

* The train stops at the departure station.
* The train stops at the destination station.
* The destination occurs later in the route than the departure.

Only trains satisfying all three conditions are displayed.

---

## What TrenLookup Does NOT Do

TrenLookup is not a route planner.

The following features are intentionally outside the scope of the project:

* Connecting train searches
* Multi-leg journey planning
* Itinerary generation
* Fare calculation
* Ticket purchasing
* Seat reservations
* Alternative route suggestions

For example:

```text
Pisa -> Florence -> Bologna
```

requires a train change and is not handled by TrenLookup.

TrenLookup only works when both selected stations exist on the same physical train route.

---

## How It Works

### 1. Station Resolution

The station search dialog uses the ViaggiaTreno autocomplete endpoint to convert station names into internal station identifiers.

Example:

```text
VIAREGGIO -> S06040
```

### 2. Departure Retrieval

The program retrieves live departures from the selected departure station.

### 3. Route Verification

Each candidate train is inspected using the train movement endpoint.

The script compares:

* Departure station ID
* Destination station ID
* Route ordering

A train is considered valid only when:

```text
Destination station occurs after departure station in the train route.
```

This prevents false positives caused by:

* Opposite-direction trains
* Similar destination names
* Trains sharing only part of a route

---

## Why This Is Needed

Trenitalia departure boards usually display something like:

```text
REG 18361
LA SPEZIA CENTRALE
```

but often do not indicate every intermediate station.

If you are traveling to an intermediate stop, it may not be obvious whether a train serves your destination.

Regional tickets frequently omit train numbers entirely because they are valid on qualifying services for that route and date.

TrenLookup removes the guesswork by verifying the train's actual route before displaying results.

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
* Raw API responses
* Station resolution results
* Departure information
* Route validation checks
* Route stop information
* Direction verification

---

## Configuration

The script contains two configuration sections near the top.

### User Settings

Used for normal customization:

```perl
my $DEBUG_FILE   = "$ENV{HOME}/.train_lookup_debug.txt";
my $VERBOSE      = (@ARGV && $ARGV[0] eq '-v') ? 1 : 0;
my $CURL_TIMEOUT = 10;
```

### System Settings

Contains the ViaggiaTreno API endpoints.

These URLs may occasionally change if Trenitalia or RFI modifies the backend.

```perl
my $API_AUTOCOMPLETE = "...";
my $API_PARTENZE     = "...";
my $API_ANDAMENTO    = "...";
```

---

## Notes

This project uses publicly accessible ViaggiaTreno endpoints.

The ViaggiaTreno backend is unofficial and undocumented. Endpoint formats, URLs, and response structures may change without notice.

The API URLs have been isolated into a dedicated configuration section to simplify future maintenance.

Live railway information is inherently dynamic. Delays, platform assignments, train compositions, and routing information can change at any time.

Results should be treated as:

> The most accurate information available at the moment the query was performed.

---

## Disclaimer

This project is an independent utility and is not affiliated with, endorsed by, sponsored by, or supported by Trenitalia, RFI, or ViaggiaTreno.

All trademarks, logos, and service names belong to their respective owners.
