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

define do-sample
	dmd $(FLAGS) $(SRC) sample/common.d sample/$1 -of$(OUTPUT)/$1
endef

samples: clean
	$(call do-sample,users)
	$(call do-sample,due)
	$(call do-sample,repo2wiki)

unittest:
	dmd $(SRC) "test/harness.d" -unittest -version=PhabUnitTest -of$(OUTPUT)/${NAME}
	./$(OUTPUT)/$(NAME) > $(OUTPUT)/test.log
	diff -u $(OUTPUT)/test.log test/expected.log

style:
ifdef STYLE
	gstyle
endif

clean:
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/*
