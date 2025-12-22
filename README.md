# Xystle
Xystle is a command-line tool that reverse-engineers
[ZeroGPT](https://www.zerogpt.com)'s API to efficiently leverage its free API
(upto 15K characters) on the terminal.

ZeroGPT itself is used to check for AI-generated content in text (subject to inaccuracies).

For your convenience, Xystle also appealingly highlights the parts of your input
that ZeroGPT detected as AI-generated. A demonstration of this is shown in the
image below.

> [!NOTE] 
> Server authentication is not handled. You cannot use Xystle to query
> from a subscribed account. This may be implemented in an upcoming release.

# Demo
![](https://files.catbox.moe/7gn11e.png)

# Installation
Xystle has officially only been tested on a Linux AMD64 system.

### Prebuilt Binaries
You can download prebuilt binaries from [Github Releases](https://github.com/eeriemyxi/xystle/releases/latest). Platforms included:
- Linux AMD64

### Compile from Source
Xystle was developed using the [Odin](https://odin-lang.org) programming language.

```bash
git clone --recurse-submodules https://github.com/eeriemyxi/xystle
cd xystle
make
bin/xystle -help
```

# Command-line Arguments
Help: `xystle -help`
```
Usage:
        xystle [i]
Flags:
        -i:<Handle>  | Input file. Optional, reads from stdin if omitted
```
