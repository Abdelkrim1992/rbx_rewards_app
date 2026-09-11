/**
 * Script to upload local app images to Supabase Storage ('app-assets' bucket)
 * 
 * Usage:
 *   node scripts/upload_assets.js [SERVICE_ROLE_KEY]
 *   OR set SUPABASE_SERVICE_ROLE_KEY in your environment.
 */

const fs = require('fs');
const path = require('path');

// 1. Read .env configuration
let supabaseUrl = '';
let serviceRoleKey = process.argv[2] || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (fs.existsSync('.env')) {
  const envLines = fs.readFileSync('.env', 'utf8').split('\n');
  for (const line of envLines) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.split('=')[1].trim();
    }
    if (!serviceRoleKey && line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) {
      serviceRoleKey = line.split('=')[1].trim();
    }
  }
}

if (!supabaseUrl) {
  console.error('❌ Missing SUPABASE_URL in .env');
  process.exit(1);
}

if (!serviceRoleKey) {
  console.log('⚠️ No SERVICE_ROLE_KEY provided.');
  console.log('Usage: node scripts/upload_assets.js <YOUR_SUPABASE_SERVICE_ROLE_KEY>');
  console.log('You can find your service_role secret key in Supabase Dashboard -> Project Settings -> API.');
  process.exit(1);
}

const MIME_TYPES = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml'
};

async function uploadAll() {
  console.log(`🚀 Connecting to Supabase: ${supabaseUrl}`);

  // 1. Ensure bucket exists
  const bucketRes = await fetch(`${supabaseUrl}/storage/v1/bucket`, {
    method: 'POST',
    headers: {
      'apikey': serviceRoleKey,
      'Authorization': `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      id: 'app-assets',
      name: 'app-assets',
      public: true,
      file_size_limit: 10485760
    })
  });

  if (bucketRes.status === 200 || bucketRes.status === 201) {
    console.log('✅ Bucket "app-assets" created or ready.');
  } else {
    const text = await bucketRes.text();
    console.log(`ℹ️ Bucket check status ${bucketRes.status}: ${text}`);
  }

  // 2. Read images
  const imagesDir = path.join(__dirname, '..', 'assets', 'images');
  const files = fs.readdirSync(imagesDir).filter(f => {
    const ext = path.extname(f).toLowerCase();
    return !f.endsWith('.bak') && ['.png', '.jpg', '.jpeg', '.webp', '.svg'].includes(ext);
  });

  console.log(`📦 Found ${files.length} images to upload...`);

  let uploadedCount = 0;
  for (const file of files) {
    const filePath = path.join(imagesDir, file);
    const fileData = fs.readFileSync(filePath);
    const ext = path.extname(file).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const storagePath = `images/${file}`;

    console.log(`Uploading ${file} (${(fileData.length / 1024).toFixed(1)} KB)...`);

    const uploadRes = await fetch(`${supabaseUrl}/storage/v1/object/app-assets/${storagePath}`, {
      method: 'POST',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': contentType,
        'x-upsert': 'true'
      },
      body: fileData
    });

    if (uploadRes.ok) {
      const publicUrl = `${supabaseUrl}/storage/v1/object/public/app-assets/${storagePath}`;
      console.log(`  ✅ Uploaded: ${publicUrl}`);
      uploadedCount++;
    } else {
      const err = await uploadRes.text();
      console.error(`  ❌ Failed to upload ${file}: ${err}`);
    }
  }

  console.log(`\n🎉 Upload Complete! ${uploadedCount}/${files.length} images uploaded.`);
  console.log(`CDN Base URL: ${supabaseUrl}/storage/v1/object/public/app-assets/images/`);
}

uploadAll().catch(err => {
  console.error('Fatal upload error:', err);
  process.exit(1);
});
