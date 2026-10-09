const fs = require('fs');
const path = require('path');

const outDir = path.join('generated');
fs.mkdirSync(outDir, { recursive: true });

for (const name of ['newsletter', 'welcome']) {
  const source = fs.readFileSync(path.join('src', name + '.md'), 'utf8');
  fs.writeFileSync(
    path.join(outDir, name + '.html'),
    '<!doctype html><title>' + name + '</title><p>' + source + '</p>\n'
  );
}

console.log('wrote generated/newsletter.html');
console.log('wrote generated/welcome.html');
