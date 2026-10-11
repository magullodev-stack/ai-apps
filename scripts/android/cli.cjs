const path = require('node:path');
const { Sessions } = require('./sessions.cjs');
const { Windows } = require('./windows.cjs');

async function main(args) {
  const [root, action, value] = args;
  const service = new Sessions(path.resolve(root), new Windows(path.resolve(root)));
  let result;
  if (action === 'Register') result = service.register(JSON.parse(require('node:fs').readFileSync(0, 'utf8')));
  else if (action === 'Capture') result = await service.capture(value);
  else if (action === 'List') result = await service.list();
  else if (action === 'Start') { await service.start(value); result = { requested: 'start', id: value }; }
  else if (action === 'Stop') { await service.stop(value); result = { requested: 'stop', id: value }; }
  else if (action === 'Unregister') { await service.unregister(value); result = { requested: 'unregister', id: value }; }
  else throw new Error('Unknown Android session action');
  console.log(JSON.stringify(result, null, 2));
}
main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
