build:
	coffee -bwc *.coffee

deploy:
	ssh node.darkhax.com "cd ~/kindlebility && make update"
	./hoptoad.sh

update:
	git pull
	git submodule init
	git submodule update
	cat public/static/bookmarklet.coffee | coffee -bcs | yui-compressor --type js -o public/static/bookmarklet.js
	mkdir -p pids logs
	coffee -bc *.coffee && node app.js restart
