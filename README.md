# Xystle
Xystle is a command-line tool that reverse-engineers
[ZeroGPT](https://www.zerogpt.com)'s API to efficiently leverage its free API
(upto 15K characters) on the terminal.

ZeroGPT itself is used for validating what proportion of your input is
AI-generated (subject to inaccuracies).

For your convenience, Xystle also appealingly highlights the parts of your input
that ZeroGPT detected as AI-generated. A demonstration of this is shown in the
image below.

> [!NOTE] 
> Server authentication is not handled. You cannot use Xystle to query
> from a subscribed account. This may be implemented in an upcoming release.

# Demo
![](https://files.catbox.moe/7gn11e.png)

# Installation
Automated prebuilt-binaries using CI/CD is planned. For now however you'll have
to compile it from source.

```bash
git clone --recurse-submodules https://github.com/eeriemyxi/xystle
cd xystle
odin build .
./xystle -help
```

# Command-line Arguments
Help: `xystle -help`
```
Usage:
        xystle [i]
Flags:
        -i:<Handle>  | Input file. Optional, reads from stdin if omitted
```
