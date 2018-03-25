SRC=$(shell find src/ -name "*.d")
OUTPUT=bin
NAME=phabricator-d

.PHONY: all

FLAGS := -inline\
	-release\
	-O\
	-boundscheck=off\

all: clean
	dmd $(FLAGS) -c $(SRC) -of${OUTPUT}/${NAME}.so

test: unittest 

unittest:
	dmd $(SRC) "test/harness.d" -unittest -version=PhabUnitTest -of$(OUTPUT)/${NAME}
	./$(OUTPUT)/$(NAME) > $(OUTPUT)/test.log
	diff -u $(OUTPUT)/test.log test/expected.log

clean:
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/*
