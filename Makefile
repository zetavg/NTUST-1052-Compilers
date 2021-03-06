TESTS = tokens-check symtab-check ast-check idtab-check scanner-test parser-test compiler-test

.SECONDARY:
.PHONY: clean test

CFLAGS += -std=c99

LLVM_CONFIG = $(shell which llvm-config || echo "`brew --prefix llvm`/bin/llvm-config")

all: bin/parser bin/scanner bin/compiler

test: $(TESTS)

clean:
	rm -f */*.o bin/parser bin/scanner bin/compiler src/y.output src/y.tab.h src/y.tab.c src/lex.yy.c tests/*-check tests/*-check.c

bin/compiler: src/compiler.o src/tokens.o src/symtab.o src/ast.o src/idtab.o src/codegen.o
	g++ -o $@ $^ -ll `$(LLVM_CONFIG) --cflags --libs --system-libs --ldflags`

bin/parser: src/standalone_parser.o src/tokens.o src/symtab.o src/ast.o src/idtab.o
	gcc $(CFLAGS) -o $@ $^ -ll

bin/scanner: src/standalone_scanner.o src/tokens.o src/symtab.o
	gcc $(CFLAGS) -o $@ $^ -ll -lm

src/compiler.o: src/compiler.c src/y.tab.c
	gcc $(CFLAGS) -w -o $@ -c $< `$(LLVM_CONFIG) --cflags`

src/standalone_parser.o: src/standalone_parser.c src/y.tab.c
	gcc $(CFLAGS) -o $@ -c $<

src/standalone_scanner.o: src/standalone_scanner.c src/lex.yy.c
	gcc $(CFLAGS) -o $@ -c $<

src/lex.yy.c: src/scanner.l
	lex -o $@ $<

src/y.tab.h src/y.tab.c: src/parser.y src/lex.yy.c
	yacc src/parser.y --output=src/y.tab.c --defines=src/y.tab.h --verbose

src/codegen.o: src/codegen.c
	gcc $(CFLAGS) -o $@ -c $< `$(LLVM_CONFIG) --cflags`

src/tokens.o: src/tokens.c src/tokens.h src/y.tab.h
	gcc $(CFLAGS) -o $@ -c $<

src/%.o: src/%.c src/%.h src/y.tab.h
	gcc $(CFLAGS) -o $@ -c $<

%-check: tests/%-check
	$<

compiler-test: bin/compiler
	tests/compiler-test.bats && echo

parser-test: bin/parser
	tests/parser-test.bats && echo

scanner-test: bin/scanner
	tests/scanner-test.bats && echo

tests/%-check: src/%.o tests/%-check.o src/tokens.o
	gcc $(CFLAGS) -w $^ -o $@ `pkg-config --cflags --libs check`

tests/%-check.o: tests/%-check.c src/y.tab.h
	gcc $(CFLAGS) -w -c $< -o $@

tests/%-check.c: tests/%-test.check
	checkmk $< > $@
