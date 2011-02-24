deploy:
  ssh node.darkhax.com "cd ~/kindlebility && make update"

update:
  git pull
  git submodule init
  git submodule update
  coffee -c *.coffee && forever restart -l forever.log -o out.log -e err.log server.js
