/**
 * Fix Unicode Emoji Mojibake
 *
 * Replaces Unicode emojis with ASCII equivalents in sync engine files
 * to fix display issues in Windows console output.
 *
 * Emoji → ASCII mappings:
 * - ✓ → [OK]
 * - ✅ → [OK]
 * - ⏳ → [...]
 * - ⚠️ → [WARN]
 * - 📋 → [INFO]
 * - ❌ → [ERROR]
 * - ✗ → [X]
 * - 🎉 → [SUCCESS]
 * - 🧪 → [TEST]
 * - 📊 → [STATS]
 * - 💡 → [TIP]
 */

const fs = require('fs');
const path = require('path');

// Unicode to ASCII replacements (emojis and special characters)
const replacements = [
  // Emojis
  { emoji: '✅', ascii: '[OK]', name: 'checkmark-box' },
  { emoji: '✓', ascii: '[OK]', name: 'checkmark' },
  { emoji: '⏳', ascii: '[...]', name: 'hourglass' },
  { emoji: '⚠️', ascii: '[WARN]', name: 'warning' },
  { emoji: '📋', ascii: '[INFO]', name: 'clipboard' },
  { emoji: '❌', ascii: '[ERROR]', name: 'x-mark' },
  { emoji: '✗', ascii: '[X]', name: 'x' },
  { emoji: '🎉', ascii: '[SUCCESS]', name: 'party' },
  { emoji: '🧪', ascii: '[TEST]', name: 'test-tube' },
  { emoji: '📊', ascii: '[STATS]', name: 'bar-chart' },
  { emoji: '💡', ascii: '[TIP]', name: 'bulb' },
  { emoji: '🛡️', ascii: '[SAFE]', name: 'shield' },
  { emoji: '📁', ascii: '[FOLDER]', name: 'folder' },
  { emoji: '📖', ascii: '[DOCS]', name: 'book' },
  { emoji: '🔑', ascii: '[KEY]', name: 'key' },
  { emoji: '🛠️', ascii: '[TOOLS]', name: 'tools' },
  { emoji: '🚨', ascii: '[ALERT]', name: 'alarm' },
  { emoji: '📚', ascii: '[LIBRARY]', name: 'books' },
  { emoji: '⭐', ascii: '[*]', name: 'star' },
  { emoji: '🎯', ascii: '[GOAL]', name: 'target' },
  { emoji: '🔒', ascii: '[LOCK]', name: 'lock' },
  { emoji: '📞', ascii: '[CONTACT]', name: 'phone' },
  { emoji: '•', ascii: '-', name: 'bullet' },
  // Arrows and special characters
  { emoji: '→', ascii: '->', name: 'right-arrow' },
  { emoji: '←', ascii: '<-', name: 'left-arrow' },
  { emoji: '↔', ascii: '<->', name: 'bidirectional-arrow' },
  { emoji: '◀', ascii: '<', name: 'left-triangle' },
  { emoji: '▶', ascii: '>', name: 'right-triangle' },
  { emoji: '│', ascii: '|', name: 'vertical-bar' },
  { emoji: '─', ascii: '-', name: 'horizontal-bar' },
  { emoji: '├', ascii: '+', name: 'branch' },
  { emoji: '└', ascii: '\\', name: 'corner' },
  // Additional arrows
  { emoji: '↑', ascii: '^', name: 'up-arrow' },
  { emoji: '↓', ascii: 'v', name: 'down-arrow' },
  { emoji: '▲', ascii: '^', name: 'up-triangle' },
  { emoji: '▼', ascii: 'v', name: 'down-triangle' },
  // Additional box-drawing characters
  { emoji: '┌', ascii: '+', name: 'corner-top-left' },
  { emoji: '┐', ascii: '+', name: 'corner-top-right' },
  { emoji: '┘', ascii: '+', name: 'corner-bottom-right' },
  { emoji: '┤', ascii: '+', name: 'branch-left' },
  { emoji: '┬', ascii: '+', name: 'branch-down' },
  { emoji: '┴', ascii: '+', name: 'branch-up' },
  { emoji: '┼', ascii: '+', name: 'cross' },
  // Special symbols
  { emoji: '🚀', ascii: '[>>]', name: 'rocket' },
];

// Files to process (all operator-facing files)
const filesToProcess = [
  // Sync engines
  'sync/reverse-sync-engine.js',
  'sync/engine-staging.js',
  'sync/production/reverse-sync-engine.js',
  'sync/production/runner-staging.js',
  'sync/production/engine-staging.js',
  'sync/production/reverse-sync-runner.js',
  'sync/runner-staging.js',
  'sync/reverse-sync-runner.js',
  // Test scripts
  'scripts/test-metadata-seed.js',
  'scripts/test-non-production-reverse-sync.js',
  'scripts/test-reverse-sync-metadata.js',
  'scripts/test-reverse-sync.js',
  'scripts/test-supabase-connection.js',
  'scripts/test-timestamp-validation.js',
  'scripts/test-reverse-sync-bootstrap.js',
  'scripts/test-reverse-sync-watermark.js',
  'scripts/test-bidirectional-sync-complete.js',
  // Setup scripts
  'scripts/create-reverse-sync-metadata-table.js',
  'scripts/create-sync-metadata-table.js',
  // Documentation (operator-facing)
  'sync/README.md',
  'sync/SYNC-ENGINE-ETL-GUIDE.md',
  'sync/production/README.md',
];

function fixFile(filePath) {
  const fullPath = path.join(process.cwd(), filePath);

  if (!fs.existsSync(fullPath)) {
    console.log(`[SKIP] File not found: ${filePath}`);
    return;
  }

  let content = fs.readFileSync(fullPath, 'utf8');
  let modified = false;
  let replacementCount = 0;

  // Apply all replacements
  for (const { emoji, ascii, name } of replacements) {
    // Count occurrences before replacement
    const matches = (content.match(new RegExp(emoji, 'g')) || []).length;

    if (matches > 0) {
      content = content.replace(new RegExp(emoji, 'g'), ascii);
      modified = true;
      replacementCount += matches;
      console.log(`  - Replaced ${matches}x ${name} (${emoji} → ${ascii})`);
    }
  }

  if (modified) {
    fs.writeFileSync(fullPath, content, 'utf8');
    console.log(`[OK] Fixed ${filePath} (${replacementCount} replacements)\n`);
  } else {
    console.log(`[SKIP] No emojis found in ${filePath}\n`);
  }
}

console.log('━'.repeat(60));
console.log('Fixing Unicode Emoji Mojibake in Sync Files');
console.log('━'.repeat(60));
console.log('');

let totalFiles = 0;
let totalReplacements = 0;

for (const file of filesToProcess) {
  console.log(`Processing: ${file}`);
  fixFile(file);
  totalFiles++;
}

console.log('━'.repeat(60));
console.log(`Processed ${totalFiles} files`);
console.log('━'.repeat(60));
console.log('');
console.log('[INFO] Unicode emojis replaced with ASCII equivalents');
console.log('[INFO] Console output should now display correctly in Windows CMD');
console.log('');
