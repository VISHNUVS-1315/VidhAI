import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

// Read SCREENSHOT_MANIFEST directly from src/data/screenshots.ts or verify public/screenshots
const manifestPath = path.join(projectRoot, 'src', 'data', 'screenshots.ts');
if (!fs.existsSync(manifestPath)) {
  console.error(`❌ Screenshot manifest not found at: ${manifestPath}`);
  process.exit(1);
}

const manifestContent = fs.readFileSync(manifestPath, 'utf8');

// Extract all objects where verified: true
const entryRegex = /{\s*id:\s*['"]([^'"]+)['"],\s*file:\s*['"]([^'"]+)['"],\s*screenName:\s*['"]([^'"]+)['"],\s*feature:\s*['"]([^'"]+)['"],\s*language:\s*['"]([^'"]+)['"],\s*device:\s*['"]([^'"]+)['"],\s*verified:\s*true,\s*capturedAt:\s*['"]([^'"]+)['"],\s*description:\s*['"]([^'"]+)['"],\s*}/gs;

let match;
let verifiedCount = 0;
let failedCount = 0;

console.log('🔍 Starting Screenshot Integrity Verification...');

while ((match = entryRegex.exec(manifestContent)) !== null) {
  const [, id, file, screenName, feature, , , , description] = match;
  verifiedCount++;

  console.log(`\nChecking verified screenshot [${id}]:`);

  // 1. Check relative path inside public directory
  const relativeFile = file.startsWith('/') ? file.slice(1) : file;
  const diskPath = path.join(projectRoot, 'public', relativeFile);

  if (!fs.existsSync(diskPath)) {
    console.error(`  ❌ File missing on disk: ${diskPath}`);
    failedCount++;
    continue;
  }

  // 2. Check file size
  const stats = fs.statSync(diskPath);
  if (stats.size === 0) {
    console.error(`  ❌ File exists but is empty (0 bytes): ${diskPath}`);
    failedCount++;
    continue;
  }

  // 3. Check required metadata
  if (!screenName || screenName.trim().length === 0) {
    console.error(`  ❌ Missing screenName (alt text) for [${id}]`);
    failedCount++;
    continue;
  }

  if (!feature || feature.trim().length === 0) {
    console.error(`  ❌ Missing feature attribute for [${id}]`);
    failedCount++;
    continue;
  }

  if (!description || description.trim().length === 0) {
    console.error(`  ❌ Missing description for [${id}]`);
    failedCount++;
    continue;
  }

  console.log(`  ✓ File exists: ${relativeFile} (${(stats.size / 1024).toFixed(1)} KB)`);
  console.log(`  ✓ Alt text: "${screenName}"`);
  console.log(`  ✓ Feature: "${feature}"`);
}

if (verifiedCount === 0) {
  console.error('❌ No verified screenshots found in manifest!');
  process.exit(1);
}

if (failedCount > 0) {
  console.error(`\n❌ Screenshot integrity check FAILED: ${failedCount} error(s) found.`);
  process.exit(1);
}

console.log(`\n✅ All ${verifiedCount} verified screenshots passed integrity check!`);
