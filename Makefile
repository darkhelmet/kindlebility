deploy:
	ssh node.darkhax.com "cd ~/kindlebility && make update"

update:
	git pull
	git submodule init
	git submodule update
	cat public/static/bookmarklet.coffee | coffee -bcs | yui-compressor --type js -o public/static/bookmarklet.js
	coffee -bc *.coffee && forever restart -l forever.log -o out.log -e err.log server.js
