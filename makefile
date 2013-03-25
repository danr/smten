
all:
	tclsh8.5 tclmk/make.tcl

userinstall:
	cd smten ; cabal install --builddir ../build/smten-$(USER) --force-reinstalls
	cd smten-smt ; cabal install --builddir ../build/smten-smt-$(USER) --force-reinstalls
	cd smten-bin ; cabal install --builddir ../build/smten-bin-$(USER) --force-reinstalls

testio:
	./build/home/.cabal/bin/smten --io \
		--include smten/share/lib \
		--file smten/share/lib/Smten/Tests/Concrete.smtn \
		--main-is Smten.Tests.Concrete.main +RTS -p

testsugar:
	./build/home/.cabal/bin/smten --desugar \
		--include smten/share/lib \
		--file smten/smtn/Smten/Tests/Concrete.smtn \
		-o desugared

clean:
	rm -rf build/smten-smt build/smten build/smten-bin build/test


