all:
	@objfw-compile -Werror --package ObjOpenSSL -o ObjWebServer	\
		ConfigParser.m						\
		ObjWebServer.m
	@mkdir -p modules
	@objfw-compile --plugin -o modules/static StaticModule.m

clean:
	rm -fr modules
	rm -f ObjWebServer *.o *~
