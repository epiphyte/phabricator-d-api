SRC=$(shell find src/ -name "*.d")
OUTPUT=bin
NAME=phabricator-d
STYLE := $(shell command -v gstyle 2> /dev/null)

.PHONY: all

FLAGS := -inline\
	-release\
	-O\
	-boundscheck=off\

all: clean
	dmd $(FLAGS) -c $(SRC) -of${OUTPUT}/${NAME}.so

test: unittest style

unittest:
	dmd $(SRC) "test/harness.d" -unittest -version=PhabUnitTest -of$(OUTPUT)/${NAME}
	./$(OUTPUT)/$(NAME)

style:
ifdef STYLE
	gstyle
endif

clean:
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/*
