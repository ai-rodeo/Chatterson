#!/usr/bin/env node

const fs = require('fs');
const { Client } = require('pg');

const DATABASE_URL = 'postgresql://postgres.ntbqncyqettduuycmzpk:czc-xpt0jtj1dzk*HJF@aws-0-us-west-1.pooler.supabase.com:6543/postgres';

async function executeSqlFile(client, filePath) {
  const sql = fs.readFileSync(filePath, 'utf8');

  console.log(`\n📄 Executing: ${filePath}`);

  try {
    await client.query(sql);
    console.log('   ✅ Success');
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    throw error;
  }
}

async function main() {
  const migrations = [
    'supabase/migrations/20250101000001_create_core_tables.sql',
    'supabase/migrations/20250101000002_enable_rls.sql',
    'supabase/migrations/20250101000003_seed_data.sql',
    'supabase/migrations/20250101000004_create_storage_bucket.sql'
  ];

  console.log('🚀 Starting Supabase migrations...');
  console.log(`   Connecting to: ntbqncyqettduuycmzpk.supabase.co\n`);

  const client = new Client({
    connectionString: DATABASE_URL,
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    console.log('✅ Connected to database\n');

    for (const migration of migrations) {
      await executeSqlFile(client, migration);
    }

    console.log('\n🎉 All migrations completed successfully!');

    // Verify tables were created
    console.log('\n📊 Verifying tables...');
    const result = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN ('organizations', 'users', 'memberships', 'assets', 'asset_files', 'asset_index')
      ORDER BY table_name;
    `);

    console.log(`   Found ${result.rows.length} tables:`);
    result.rows.forEach(row => console.log(`     - ${row.table_name}`));

    // Check seed data
    const orgResult = await client.query('SELECT id, name, type FROM public.organizations ORDER BY type, name;');
    console.log(`\n🏢 Organizations created: ${orgResult.rows.length}`);
    orgResult.rows.forEach(row => console.log(`     - ${row.name} (${row.type})`));

  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
