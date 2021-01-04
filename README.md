# Hex Fiend template for PostgreSQL heap files

This template for [HexFiend][1] allows you to inspect PostgreSQL heap files.

This can be useful for doing post-mortem analysis of corrupted storage, exploring and teaching PostgreSQL internals.

⚠️ This should go without saying, but you should never manipulate PostgreSQL data files. Even when there are articles on the internet suggesting that.


## Installation and Usage

### Install the Template
You’ll need Hex Fiend 2.9.0 or later, however, this script is only tested with [Hex Fiend 2.14.0][2].

Download the `PostgreSQLHeap.tcl` Script and save it in `~/Library/Application Support/com.ridiculousfish.HexFiend/Templates`

```bash
curl https://raw.githubusercontent.com/tbartelmess/PostgreSQL-Hexfiend/main/PostgreSQLHeap.tcl > ~/Library/Application\ Support/com.ridiculousfish.HexFiend/Templates
```

Open a PostgreSQL Heap file in HexFiend, open the “Binary Template” section (Views-\>Binary Templates) and select “PostgreSQL Heap”.

![Screenshot of HexFiend using the PostgreSQL heap template][image-1]

[1]:	(http://ridiculousfish.com/hexfiend/
[2]:	https://github.com/HexFiend/HexFiend/releases/tag/v2.14.0

[image-1]:	docs/screenshot.png