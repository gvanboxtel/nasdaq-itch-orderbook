# Nasdaq ITCH order book

A feed handler that reads one trading day of Nasdaq TotalView-ITCH 5.0 messages and rebuilds the order book of every stock from them.

## Language

### Instruments

**Stock**:
A tradable instrument on Nasdaq, such as Apple.
_Avoid_: Instrument, security, ticker

**Symbol**:
The 8-character, space-padded name of a stock (`AAPL    `), as typed on the command line.
_Avoid_: Ticker, stock name

**Locate**:
The number Nasdaq assigns to a stock for one day, carried in every message instead of the symbol.
_Avoid_: Stock id, stock index

### Orders

**Order reference**:
The number that identifies one order for the whole day.
_Avoid_: Order id, order number

**Execution**:
Shares of a displayed order on the book being matched against an incoming order (`E` or `C`).
_Avoid_: Fill, trade, match

**Trade**:
A match involving a non-displayed order (`P`), which never touches the book.
_Avoid_: Execution, print
