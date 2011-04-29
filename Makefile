build:
	coffee -bwc *.coffee

deploy:
	ssh node.darkhax.com "cd ~/kindlebility && make update"
	./hoptoad.sh

bookmarklet:
	cat public/static/bookmarklet.coffee | coffee -bcs > public/static/bookmarklet.js

update:
	git pull
	git submodule init
	git submodule update
	cat public/static/bookmarklet.coffee | coffee -bcs | yui-compressor --type js -o public/static/bookmarklet.js
	mkdir -p pids
	mkdir -p logs
	coffee -bc *.coffee
	kill -2 `cat node.*.pid`
