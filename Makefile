SRC=$(shell find src/ -name "*.d")
OUTPUT=bin
NAME=phabricator-d
SAMPLES=$(shell ls sample/ | grep -v "common.d" | sed "s/\.d//g")

.PHONY: all

FLAGS := -inline\
	-release\
	-O\
	-boundscheck=off\

all: clean
	dmd $(FLAGS) -c $(SRC) -of${OUTPUT}/${NAME}.so

test: unittest 

define do-sample
endef

samples: $(SAMPLES)

$(SAMPLES): clean
	dmd $(FLAGS) $(SRC) sample/common.d sample/$@.d -of$(OUTPUT)/$@

unittest:
	dmd $(SRC) "test/harness.d" -unittest -version=PhabUnitTest -of$(OUTPUT)/${NAME}
	./$(OUTPUT)/$(NAME) > $(OUTPUT)/test.log
	diff -u $(OUTPUT)/test.log test/expected.log

clean:
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/*
