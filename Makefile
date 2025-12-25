OPTIMIZATION = aggressive
BIN = bin
PLATFORM = linux_amd64
TARGET = $(BIN)/xystle
COMP_DATE = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_HASH = $(shell git rev-parse --short HEAD)
VERSION = $(shell git describe --tags --dirty --always)

.PHONY: all clean

all: $(TARGET)

$(BIN):
	mkdir -p $(BIN)

$(TARGET): | $(BIN)
	odin build . -out:$(TARGET) -o:$(OPTIMIZATION) -target:$(PLATFORM) -define:VERSION=$(VERSION) -define:GIT_HASH=x$(GIT_HASH) -define:COMP_DATE=$(COMP_DATE)

clean:
	rm -f $(TARGET)
	rmdir $(BIN) 2>/dev/null || true
