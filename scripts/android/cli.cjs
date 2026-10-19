const path = require('node:path');
const fs = require('node:fs');
const {Sessions} = require('./sessions.cjs');
const {Windows} = require('./windows.cjs');
async function main(args) {
  const [root, action, value] = args;
  const service = new Sessions(path.resolve(root), new Windows(path.resolve(root)));
  let result;
  if (action === 'Register') result = service.register(JSON.parse(fs.readFileSync(0, 'utf8')));
  else if (action === 'List') result = await service.list();
  else if (action === 'Unregister') { await service.unregister(value); result = {removed: value}; }
  else throw new Error('Flutter se inicia y detiene desde VS Code, no desde un worker.');
  console.log(JSON.stringify(result, null, 2));
}
main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
