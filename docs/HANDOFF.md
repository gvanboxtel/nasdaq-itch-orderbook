# Overdracht: nasdaq-itch-orderbook

## Doel
In 2 à 3 weken (5 à 8 uur per week) ontdekken of ik software engineering bij een
market maker zoals Optiver leuk vind. Focus op low-level engineering (snelheid en
correctheid), met net genoeg finance: bid/ask, spread, order book en order types.
Het project moet ook een goede indruk maken op Optiver.

## Project (staat vast)
- Repo: github.com/gvanboxtel/nasdaq-itch-orderbook
  Lokaal: C:\Users\gijsv\Documents\Codam\nasdaq-itch-orderbook
  Inhoud nu: Initial commit, .gitignore, SUBJECT.md (nog niet gecommit).
- SUBJECT.md (in 42-stijl) is de bron van waarheid voor eisen, CLI, referentiewaarden
  en evaluatiedrempels.
- Wat het is: een feed handler en order book voor Nasdaq TotalView-ITCH 5.0, in modern
  C++20 (idiomatisch, zoals het hoort).
- CLI `itch-book`, met twee modi:
  - `stats <file>`
  - `book <file> --symbol SYM --time HH:MM:SS [--depth N] [--check]`
- Fases:
  1. parser en stats, inclusief een afgekapt bestand;
  2. order book en correctheid;
  3. de hele dag draaien, benchmark en perf, README.
- Bonussen: latency-histogram, eigen hash map, eigen prijsniveaus, een trades/VWAP-modus,
  en een naïeve market maker.
- Rollen: ik schrijf alle code. Claude legt uit, stelt vragen en reviewt streng, zoals
  een senior bij Optiver dat zou doen. Geen oplossingen, hooguit mini-voorbeelden van
  syntax.

## Omgeving (staat vast)
- Ontwikkelen: Windows met Git Bash. Toolchain: MinGW-w64 g++ 16.1 (WinLibs),
  CMake 4.4, Ninja.
- MinGW heeft geen ASan (het linken faalt met `cannot find -lasan`). Sanitizers
  (ASan/UBSan), perf en de officiële benchmarks draaien daarom op mijn Ubuntu-pc.
- Eis: hetzelfde CMakeLists.txt bouwt op Windows én Linux.
- Builds: Debug (asserts) en Release (-O3). Vlaggen: -Wall -Wextra -Werror.
- Tests met GoogleTest, binnengehaald via FetchContent.

## Data (staat vast)
- Dag: 12302019.NASDAQ_ITCH50.gz, op https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/
  (3,5 GB gecomprimeerd, uitgepakt geschat ~9 GB).
- Dev chunk: de eerste 128 MiB van de .gz, uitgepakt. Dat is 352.102.300 bytes en loopt
  tot ~09:32:30 ET.
  `curl -r 0-134217727 <url> | gzip -dc > ~/data/itch/dev.itch`
- Data komt nooit in de repo.

## Correctheid (staat vast)
1. Unit tests met handgemaakte bytes.
2. Invarianten onder `--check`.
3. Exacte referentiewaarden uit SUBJECT.md: tellingen per type (totaal 10.403.622
   berichten), het AAPL-book om 09:31:00, en het afgekapte bestand (33.802 berichten,
   13 bytes over).

## Benchmarkdrempels
Release-build, Linux, mediaan van 5 runs, dev chunk:
- Pass: ≥ 3 M msg/s
- Good: ≥ 10 M msg/s
- Outstanding: ≥ 25 M msg/s

Kalibratie: een MVP met std::map en std::unordered_map haalde 2,3 tot 3,4 M msg/s op
mijn laptop. Alleen berichten tellen ging met meer dan 200 M msg/s.

## Na 3 weken beslissen
Signalen:
- Werd ik enthousiast van het optimaliseren?
- Ging ik uit mezelf over beurzen lezen?
- Wil ik doorgaan?

Twee keer ja betekent: serieus overwegen om te solliciteren.
Naast het project: de mental-math- en sequence-tests proberen, één engineer van een
trading-bedrijf spreken, en kijken naar hun events.

## Nog open: project board en CI (onderwerp van de volgende sessie)
- Project board: GitHub Projects (v2). Kolommen en statussen? Milestones per fase of per
  week? Labels?
- Issues: hoe snijden we SUBJECT.md op (verticale slices)? Hoe groot is één issue?
  Branchnamen volgen `<N>-...` per issue.
- CI-matrix: ubuntu-latest en windows-latest (MinGW)? Welke compilers, gcc en/of clang?
- Sanitizer-job op Linux bij elke push of PR?
- Referentietests op de dev chunk in CI? 128 MB per run downloaden van de Nasdaq-server,
  of cachen met actions/cache, of alleen lokaal?
- Benchmark in CI? Gedeelde runners geven ruis, dus wel draaien en rapporteren, maar
  niet laten falen op een drempel?
- Kwaliteit: clang-format en/of clang-tidy als check? Warnings als errors staan al vast.
- Branch protection: CI verplicht groen voordat er gemerged wordt? Reviews?
- Hoe passen de README-eisen (benchmarkcijfers, uitleg in eigen woorden) in het board?
