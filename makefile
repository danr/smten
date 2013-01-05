
all:
	tclsh8.5 tclmk/make.tcl

test:
	./build/seri-bin/seri --haskellf \
		--include seri/sri \
		--main-is main \
		-f seri/sri/Seri/TSPLIB/HCP/HCP.sri +RTS -p > foo.hs
	HOME=build/home ghc -fno-warn-overlapping-patterns \
		-fno-warn-missing-fields \
		-main-is __main \
		-prof -auto-all -rtsopts \
		-o foo foo.hs
	./foo +RTS -p -K1g

testio:
	./build/home/.cabal/bin/seri --io \
		--include seri/sri \
		--main-is Seri.SMT.Tests.Sudoku2.main \
		-f seri/sri/Seri/SMT/Tests/Sudoku2.sri +RTS -p

userinstall:
	cd seri ; cabal install --builddir ../build/seri-$(USER) --force-reinstalls
	cd seri-smt ; cabal install --builddir ../build/seri-smt-$(USER) --force-reinstalls
	cd seri-bin ; cabal install --builddir ../build/seri-bin-$(USER) --force-reinstalls

clean:
	rm -rf build/seri-smt build/seri build/seri-bin build/test


