

# ROM-Patch-Version
F=xorsh32bit


all: $(F).o


### ROM-Patch-Version

$(F).o: $(F).asm loader.asm
	acme -v3 -l $(F).l -r $(F).r $(F).asm 


clean:
	rm $(F).o *.l *.r


