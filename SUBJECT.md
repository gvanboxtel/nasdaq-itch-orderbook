# nasdaq_itch_orderbook

*How fast can you know what the market looks like?*

> Summary: Parse a full trading day of real Nasdaq market data and rebuild every order book from it, correctly first, then fast.
> Version: 1.0

---

## Chapter I — Foreword

In 1850 the telegraph line from Berlin stopped at Aachen and the Belgian line started in Brussels. Between the
two, news travelled by train. Paul Julius Reuter closed the gap with 45 carrier pigeons and beat the train by
hours. Bankers paid for the difference.

The pigeons are gone. The gap is now measured in nanoseconds, and it lives in the code that turns a stream of
exchange messages into a picture of the market. You are going to write that code.

---

## Chapter II — Objectives

By the end you will have built:

1. A **parser** for Nasdaq **TotalView-ITCH 5.0**, the binary feed that describes every order on Nasdaq.
2. An **order book** per stock, rebuilt message by message from that feed, that you can query at any moment
   of the day.
3. A **benchmark** that tells you, with numbers you trust, how many messages per second your book handles and
   where the time goes.

The intent is numerical. "It works" is the start: correctness is checked against reference values below, and
speed is measured, not felt.

---

## Chapter III — General instructions

- Language: **C++20**. Write idiomatic modern C++: RAII, value types, `std::` containers where they fit.
  Building your own replacements comes later, and only when a profiler tells you to.
- Build system: **CMake**. Tests: **GoogleTest**.
- Two build types: `Debug` (assertions on) and `Release` (`-O3`). Compile with `-Wall -Wextra -Werror`.
- The project must build and pass its tests on **Windows** (Git Bash, MinGW-w64 g++) **and Linux** (Ubuntu,
  g++ or clang) from the same `CMakeLists.txt`.
- Sanitizer runs (`-fsanitize=address,undefined`), profiling and the official benchmark numbers happen on
  **Linux**.

> **⚠️ Warning**
> MinGW-w64 g++ ships without AddressSanitizer: `-fsanitize=address` fails at link time with
> `cannot find -lasan`. Don't fight it. Run sanitizers on Linux.

> **ℹ️ Info**
> Market data is never committed. Keep it outside the repo (for example `~/data/itch/`) and make sure
> `git status` stays clean after a run.

---

## Chapter IV — Mandatory part

### IV.1 The data

Nasdaq publishes full sample days at <https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/>. You use
**`12302019.NASDAQ_ITCH50.gz`** (30 December 2019, 3.5 GB compressed, roughly 9 GB decompressed).

Do not start with the full day. Start with the **dev chunk**: the first 128 MiB of the compressed file,
decompressed.

```console
$ curl -r 0-134217727 "https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/12302019.NASDAQ_ITCH50.gz" \
    | gzip -dc > ~/data/itch/dev.itch
gzip: stdin: unexpected end of file
$ wc -c < ~/data/itch/dev.itch
352102300
```

The gzip complaint is expected, since you cut the stream. If your byte count differs, the reference values below
won't match either.

The dev chunk runs from midnight to about **09:32:30** Eastern time, so it includes the market open at 09:30.

### IV.2 The parser

The file is a sequence of messages, each preceded by a 2-byte big-endian length. The format of every message
type is in the specification (see Resources). One example, the Add Order message:

```
Add Order (no MPID), type 'A', 36 bytes
offset len  field
     0   1  message type       'A'
     1   2  stock locate       integer
     3   2  tracking number    integer
     5   6  timestamp          integer, nanoseconds since midnight
    11   8  order reference    integer
    19   1  side               'B' or 'S'
    20   4  shares             integer
    24   8  stock              alpha, right-padded with spaces
    32   4  price              integer, 4 implied decimals
```

Your parser must:

- Decode at least `S R A F E C X D U P` into typed C++ values. Recognise and skip every other type by its
  length.
- Handle every integer as **big-endian**, whatever the host machine is.
- Never read past the end of the buffer. A file cut in the middle of a message must produce a warning with the
  number of trailing bytes, not a crash.
- Keep decoding separate from what happens with a message, so the parser can be tested without a book.

### IV.3 The order book

For every stock, keep both sides of the book: per price level, the total number of shares resting there.

- **Add** (`A`, `F`) puts an order on the book.
- **Execute** (`E`, `C`) and **Cancel** (`X`) remove shares from an existing order. **Delete** (`D`) removes
  the whole order. **Replace** (`U`) removes the old order and adds a new one with a new reference number, at
  the same side and stock.
- An order whose shares reach zero disappears. So does a price level whose total reaches zero.
- `E`, `C`, `X`, `D` and `U` carry no symbol and no side. You get those from the original order.
- The book at time `T` is the state after every message with a timestamp **strictly before** `T`.

### IV.4 The program

One binary, `itch-book`, with two modes:

```console
$ itch-book stats <file>
$ itch-book book <file> --symbol <SYM> --time <HH:MM:SS> [--depth N] [--check]
```

- `stats` prints the count per message type, the total, the elapsed time and the throughput.
- `book` prints the top `N` price levels on each side (default `--depth 5`) for one symbol at a given time.
  If `--time` lies past the end of the file, print the book at the end and say so.
- `--check` turns on invariant checking while building the book (see IV.5) and prints a summary of the
  violations. Without the flag the checks cost nothing.

Expected output on the dev chunk (layout is yours, numbers are not):

```console
$ itch-book stats ~/data/itch/dev.itch
A 3907742   C 2072      D 3002773   E 87571     F 785665    H 8901
I 1073085   K 3         L 215089    P 22773     Q 8906      R 8906
S 3         U 729719    V 1         X 541503    Y 8910
total 10403622 messages

$ itch-book book ~/data/itch/dev.itch --symbol AAPL --time 09:31:00
AAPL @ 09:31:00.000000000   (3658 bid levels, 1077 ask levels)
        bid               ask
   60 @ 288.8500     288.9000 @ 113
  100 @ 288.8400     288.9100 @ 200
  200 @ 288.8300     288.9200 @ 200
  300 @ 288.8200     288.9300 @ 100
  300 @ 288.8100     288.9400 @ 200
```

And on a deliberately broken file:

```console
$ head -c 1000003 ~/data/itch/dev.itch > cut.itch
$ itch-book stats cut.itch
...
total 33802 messages
warning: 13 trailing bytes ignored (truncated message)
```

### IV.5 Correctness

You prove your book is right in three layers.

1. **Unit tests** (GoogleTest) with hand-built byte buffers: one Add, then an Execute, a partial Cancel, a
   Replace, a Delete. Check the book after each step. Cover big-endian decoding and truncation separately.
2. **Invariants**, checked under `--check`: no negative share counts, every `E C X D U` refers to a live order,
   and the best bid is below the best ask.
3. **Reference values**: the counts and the AAPL book in IV.4 come from an independent implementation. Yours
   must match them exactly.

> **⚠️ Warning**
> On the dev chunk your "best bid below best ask" check fires about 146 times, all before the open, starting
> with `PNRL` around 08:00. Find out whether that's your bug or the market behaving as designed. Decide what your
> checker should do about it, and explain your conclusion in the README.

### IV.6 Benchmark

- Benchmark the `Release` build on Linux.
- Time **book building only**: load the file into memory first and exclude that from the clock.
- Run at least 5 times and report the **median** in messages per second and nanoseconds per message. On a
  laptop, single runs varied by more than 30%.
- Run the **full day** once to completion and report the total message count, the time, and the peak number
  of live orders.
- Profile with `perf` and include the evidence (for example, a flame graph or the top of `perf report`) that
  shows where the time goes.

> **ℹ️ Info**
> Get it correct with the most obvious containers first. Optimising a book that's wrong only gives you fast wrong
> answers.

---

## Chapter V — Evaluation

| Criterion | Requirement |
|---|---|
| Message counts on the dev chunk | exactly as in IV.4 |
| AAPL book at 09:31:00 on the dev chunk | exactly as in IV.4 |
| Truncated file | correct count and warning, no crash |
| References to unknown orders (dev chunk and full day) | 0 |
| Unit tests | pass on Windows and Linux |
| ASan and UBSan, Linux, full test suite and the dev chunk | clean |
| Full day | completes, numbers reported in README |

**Book throughput** (Release build, Linux, dev chunk, median of 5 runs):

| Tier | Messages per second | Roughly |
|---|---|---|
| Pass | ≥ 3 M | ≤ 330 ns/msg |
| Good | ≥ 10 M | ≤ 100 ns/msg |
| Outstanding | ≥ 25 M | ≤ 40 ns/msg |

Why these numbers: a straightforward build with `std::map` per side and `std::unordered_map` for orders reached
2.3 to 3.4 M msg/s on a laptop. So **Pass** is "correct and not doing anything silly". Counting messages alone
ran at more than 200 M msg/s on the same machine. Parsing is not where the time goes. To reach **Good** and
**Outstanding**, you'll have to find out what is, and why.

---

## Chapter VI — Readme requirements

Your `README.md` must contain:

- How to build, test and run the program on Windows and on Linux, and how to get the data.
- Your benchmark results: the hardware, the compiler, the median, and the full-day run.
- **In your own words**, without code:
  - Why you need a lookup from order reference number to order, what lives in it, and what happens to the
    cache when there are 1.6 million live orders.
  - What your profiler showed, and what you changed because of it. Include the before and after numbers.
  - Your conclusion about the crossed books before the open.

---

## Chapter VII — Resources

**Foundational**
- [Optiver: Market making explained](https://www.optiver.com/insights/explainers/market-making/): the business
  your code serves, in Optiver's own words. Read it first, it takes ten minutes.

**Reference**
- [Nasdaq TotalView-ITCH 5.0 specification (PDF)](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHspecification.pdf):
  the source of truth for every message layout. Section 1.3 (Add Order) and 1.4 (Modify Order) are the core.
- [Nasdaq ITCH sample files](https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/): the data.

**The real thing**
- [Carl Cook, *When a Microsecond Is an Eternity* (CppCon 2017)](https://isocpp.org/blog/2018/09/cppcon-2017-when-a-microsecond-is-an-eternity-high-performance-trading-syst):
  low-latency C++ as practised at Optiver. Above all: measure.
- [David Gross, *When Nanoseconds Matter* (CppCon 2024)](https://isocpp.org/blog/2025/05/cppcon-2024-when-nanoseconds-matter-ultrafast-trading-systems-in-cpp-d):
  Optiver's auto-trading lead on data structures for exactly this problem. Watch it **after** your Pass version
  works, then compare his choices with yours. See also [Optiver's write-up of the talk](https://www.optiver.com/insights/technology-blog/designing-low-latency-cpp-systems/).

**Going deeper**
- [Ulrich Drepper, *What Every Programmer Should Know About Memory*](https://lwn.net/Articles/250967/):
  why your book is slow, explained from the hardware up. Parts 2 (caches) and 6 (what programmers can do)
  matter most here.
- [Brendan Gregg, perf examples](https://www.brendangregg.com/perf.html): how to make `perf` tell you where
  the time goes.

---

## Chapter VIII — Bonus part

Only once the mandatory part is perfect:

- **Latency histogram.** Measure the time per message and report p50, p99, p99.9 and the maximum. A median of
  40 ns doesn't help if one message in a thousand takes 20 µs. Find out what causes your tail.
- **Your own order map.** Write a hash table for reference number → order that beats `std::unordered_map` on
  this workload. Prove it with the benchmark.
- **Your own price levels.** Replace the tree per side with a structure built for how prices actually move
  in this data. Look at where most updates land before you design anything.
- **Time and sales.** Add a `trades` mode that prints every execution for a symbol between two times, with VWAP.
  Mind the `Printable` flag on `C` messages.
- **A naive market maker.** Quote one share at a fixed distance around the mid price of one stock. Treat any
  execution that crosses your quote as a fill, and track your position and profit and loss through the day.
  It will lose money. Explain why.

---

## Chapter IX — Submission

Push your work to your Git repository: the source, `CMakeLists.txt`, the tests and the README. Don't commit
market data, build directories or binaries.

When this is done you know what a feed handler is. Ask yourself whether the last 20% of optimising was the most
fun part. If it was, the next step is the bonus market maker. Making the book is engineering. Deciding what
to do with it is trading.
