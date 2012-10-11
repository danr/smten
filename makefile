
all:
	tclsh8.5 tclmk/make.tcl

test:
	./build/src/dist/build/seriq2/seriq2 \
		-d foo.dbg -i src \
		-m Seri.SMT.Tests.Sudoku3.main \
		src/Seri/SMT/Tests/Sudoku3.sri +RTS -p


clean:
	rm -rf build


