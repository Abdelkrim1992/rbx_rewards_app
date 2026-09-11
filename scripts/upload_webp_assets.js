const fs = require('fs');
const path = require('path');

const env = fs.readFileSync('.env', 'utf8');
const url = env.match(/SUPABASE_URL=(.*)/)[1].trim();
const key = env.match(/SUPABASE_ANON_KEY=(.*)/)[1].trim();

const webpDir = path.join(__dirname, '..', 'assets', 'webp');
const files = fs.readdirSync(webpDir).filter(f => f.endsWith('.webp'));

async function uploadAllWebp() {
  console.log(`Uploading ${files.length} WebP files to 'app-assets/webp' with 1-year immutable cache header...`);

  let success = 0;
  for (const file of files) {
    const filePath = path.join(webpDir, file);
    const data = fs.readFileSync(filePath);

    const res = await fetch(`${url}/storage/v1/object/app-assets/webp/${file}`, {
      method: 'POST',
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`,
        'Content-Type': 'image/webp',
        'cache-control': '31536000',
        'x-upsert': 'true'
      },
      body: data
    });

    if (res.ok) {
      console.log(`  ✅ Uploaded: ${file} (${(data.length / 1024).toFixed(1)} KB)`);
      success++;
    } else {
      const err = await res.text();
      console.error(`  ❌ Failed ${file}: ${err}`);
    }
  }

  console.log(`\n🎉 Completed! ${success}/${files.length} WebP images live on CDN.`);
  console.log(`CDN Base: ${url}/storage/v1/object/public/app-assets/webp/`);
}

uploadAllWebp().catch(console.error);
