OPTIMIZATION = aggressive
BIN = bin
PLATFORM = linux_amd64
TARGET = $(BIN)/xystle
GIT_HASH = $(shell git describe --tags --dirty --always)

.PHONY: all clean

all: $(TARGET)

$(BIN):
	mkdir -p $(BIN)

$(TARGET): | $(BIN)
	odin build . -out:$(TARGET) -o:$(OPTIMIZATION) -target:$(PLATFORM) -define:VERSION=$(GIT_HASH)

clean:
	rm -f $(TARGET)
	rmdir $(BIN) 2>/dev/null || true
