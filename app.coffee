Cluster = require('cluster')

cluster = Cluster('./server')
  .use(Cluster.logger('logs'))
  .use(Cluster.pidfiles('pids'))
  .use(Cluster.cli())
  .use(Cluster.repl('8080'))
  .use(Cluster.stats())
  .listen(9090)
