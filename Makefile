SRC    := $(shell find src/ -name "*.d")
OUTPUT := bin
NAME   := phabricator-d
FLAGS  := -inline -release -O -boundscheck=off
OUTDIR := -of$(OUTPUT)/$(NAME)
DMD    := dmd
TESTS  := "test/harness.d" -unittest -version=PhabUnitTest 

all: clean
	$(DMD) $(FLAGS) -c $(SRC) $(OUTDIR).so

test: unittest 

unittest:
	$(DMD) $(SRC) $(TESTS) $(OUTDIR)
	./$(OUTPUT)/$(NAME) > $(OUTPUT)/test.log
	diff -u $(OUTPUT)/test.log test/expected.log

clean:
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/*
