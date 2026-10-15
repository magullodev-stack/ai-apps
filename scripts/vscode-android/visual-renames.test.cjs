'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {planVisualRenames} = require('./visual-renames.cjs');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-apps-renames-'));
const f=(...parts)=>path.join(root,...parts);
function pair(oldPath, newPath) {
  return {oldUri:{fsPath:f(...oldPath.split('/'))},
    newUri:{fsPath:f(...newPath.split('/'))}};
}
try {
  fs.mkdirSync(f('assets','auth'),{recursive:true});
  fs.mkdirSync(f('lib','app','development'),{recursive:true});
  fs.writeFileSync(f('assets','auth','Stars.png'),'dummy');
  fs.writeFileSync(f('pubspec.yaml'), 'name: test\nflutter:\n  assets:\n    - assets/auth/\n    - assets/auth/Stars.png\n');
  fs.writeFileSync(f('lib','app','auth.dart'), [
    '// ai-apps:visual:start assets/auth/Stars.png',
    "Image.asset('assets/auth/Stars.png'),",
    '// ai-apps:visual:end assets/auth/Stars.png',
  ].join('\n')+'\n');
  fs.writeFileSync(f('lib','app','development','experiences.json'),
    JSON.stringify({version:1,experiences:[{
      id:'auth',assetDirectories:['assets/auth']}]})+'\n');
  const session={projectPath:root};
  const image=planVisualRenames(session,[pair(
    'assets/auth/Stars.png','assets/auth/Nova.png')]);
  assert.equal(image.length,2,'Dart and pubspec must change with image name');
  assert.ok(image.find(x=>x.filename.endsWith('auth.dart'))
    .updated.includes('assets/auth/Nova.png'));
  assert.ok(!image.find(x=>x.filename.endsWith('auth.dart'))
    .updated.includes('assets/auth/Stars.png'));
  assert.ok(image.find(x=>x.filename.endsWith('pubspec.yaml'))
    .updated.includes('- assets/auth/Nova.png'));
  const folder=planVisualRenames(session,[pair('assets/auth','assets/access')]);
  assert.equal(folder.length,3,'Dart, pubspec and catalog must move together');
  assert.ok(folder.find(x=>x.filename.endsWith('experiences.json'))
    .updated.includes('"assets/access"'));
  assert.ok(folder.find(x=>x.filename.endsWith('pubspec.yaml'))
    .updated.includes('- assets/access/'));
  assert.ok(folder.find(x=>x.filename.endsWith('auth.dart'))
    .updated.includes('visual:start assets/access/Stars.png'));
  assert.equal(fs.existsSync(f('assets','auth','Stars.png')),true,
    'Planning must not change files before user confirmation');
  assert.throws(()=>planVisualRenames(session,[pair(
    'assets/auth/Stars.png','assets/auth/Stars.jpg')]),/formato/);
  assert.throws(()=>planVisualRenames(session,[pair(
    'assets/auth/Stars.png','assets/home/Stars.png')]),/misma carpeta/);
} finally {fs.rmSync(root,{recursive:true,force:true});}
console.log('PASS: rename updates Dart, visual markers, catalog and pubspec');

