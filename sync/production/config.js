/**
 * Sync Configuration
 *
 * Database connection settings for syncing local Power CA PostgreSQL
 * to Supabase Cloud.
 *
 * SECURITY: Use .env file for sensitive credentials in production.
 */

require('dotenv').config();

// SECURITY: Validate required environment variables (Issue #15 Fix)
// Fail fast if critical credentials are not set in .env file
if (!process.env.SUPABASE_DB_PASSWORD) {
  throw new Error(
    'CRITICAL SECURITY ERROR: SUPABASE_DB_PASSWORD not set in .env file!\n' +
    'Please configure your .env file with the Supabase database password before running.\n' +
    'See .env.example for required environment variables.'
  );
}

const config = {
  // Source: Local Power CA PostgreSQL Database
  source: {
    host: process.env.LOCAL_DB_HOST || 'localhost',
    port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
    database: process.env.LOCAL_DB_NAME || 'powerca',
    user: process.env.LOCAL_DB_USER || 'postgres',
    password: process.env.LOCAL_DB_PASSWORD,
    // PostgreSQL connection settings
    max: 10, // Maximum pool size
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  },

  // Target: Supabase Cloud Database
  target: {
    host: process.env.SUPABASE_DB_HOST || 'aws-0-ap-south-1.pooler.supabase.com',
    port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
    database: process.env.SUPABASE_DB_NAME || 'postgres',
    user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
    password: process.env.SUPABASE_DB_PASSWORD,  // REQUIRED - validated above (Issue #15 Fix)
    ssl: {
      rejectUnauthorized: false
    },
    // Connection pool settings
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  },

  // Supabase API Configuration (for future use)
  supabase: {
    url: process.env.SUPABASE_URL || 'https://jacqfogzgzvbjeizljqf.supabase.co',
    anonKey: process.env.SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  },

  // Table Mapping Configuration
  // Maps desktop table names to mobile table names
  tableMapping: {
    'mbreminder': 'reminder',
    'mbremdetail': 'remdetail',
    // All other tables have the same name
    'orgmaster': 'orgmaster',
    'locmaster': 'locmaster',
    'conmaster': 'conmaster',
    'climaster': 'climaster',
    'cliunimaster': 'cliunimaster',
    'taskmaster': 'taskmaster',
    'jobmaster': 'jobmaster',
    'mbstaff': 'mbstaff',
    'jobshead': 'jobshead',
    'jobtasks': 'jobtasks',
    'taskchecklist': 'taskchecklist',
    'workdiary': 'workdiary',
    'learequest': 'learequest',
  },

  // Master Tables - Full Sync (replace all data)
  // These tables contain reference/lookup data that changes infrequently
  masterTables: [
    'orgmaster',
    'locmaster',
    'conmaster',
    'climaster',
    'cliunimaster',
    'taskmaster',
    'jobmaster',
    'mbstaff',
  ],

  // Transactional Tables - Incremental Sync (only changed records)
  // These tables contain frequently changing operational data
  transactionalTables: [
    'jobshead',
    'jobtasks',
    'taskchecklist',
    'workdiary',
    'mbreminder', // Desktop name
    'mbremdetail', // Desktop name
    'learequest',
  ],

  // Column Mappings for Tables with Differences
  columnMappings: {
    // jobshead: Desktop has extra columns that mobile doesn't need
    jobshead: {
      // Columns to skip from desktop (not in mobile schema)
      skipColumns: ['jctincharge', 'jt_id', 'tc_id'],  // sporg_id now in Supabase, job_uid also syncing
      // Columns to add for mobile (with default values if not in desktop)
      addColumns: {
        source: 'D', // Track data origin
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },

    // jobtasks: Mobile needs client_id (lookup from jobshead)
    jobtasks: {
      // Skip jt_id - it's auto-generated BIGSERIAL in Supabase
      skipColumns: ['jt_id'],
      addColumns: {
        source: 'D',
        created_at: () => new Date(),
        updated_at: () => new Date(),
      },
      // Special handling: need to lookup client_id from jobshead
      lookups: {
        client_id: {
          fromTable: 'jobshead',
          matchOn: 'job_id',
          selectColumn: 'client_id'
        }
      }
    },

    // mbreminder → reminder (name change)
    mbreminder: {
      skipColumns: [],
      addColumns: {
        source: 'D',
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },

    // mbremdetail → remdetail (name change)
    mbremdetail: {
      skipColumns: [],
      addColumns: {
        source: 'D',
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },

    // taskchecklist: Mobile tracking column
    taskchecklist: {
      // SKIP tc_id - Mobile-only tracking column, NOT in desktop
      skipColumns: ['tc_id'],
      addColumns: {
        source: 'D',
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },

    // workdiary: Daily work entries (mobile-input)
    workdiary: {
      // SKIP wd_id - Mobile-only tracking column
      skipColumns: ['wd_id'],
      addColumns: {
        source: 'D',
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },
  },

  // Sync Configuration
  sync: {
    // Batch size for bulk inserts
    batchSize: 1000,

    // Log sync operations
    enableLogging: true,

    // Dry run mode (don't actually write to target)
    dryRun: false,

    // Retry settings
    maxRetries: 3,
    retryDelay: 5000, // milliseconds

    // Conflict resolution
    conflictResolution: 'source-wins', // 'source-wins' | 'target-wins' | 'error'
  },

  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info', // 'debug' | 'info' | 'warn' | 'error'
    logToFile: true,
    logFilePath: './logs/sync.log',
  }
};

// Validation
function validateConfig() {
  const errors = [];

  // Check source database password
  if (!config.source.password) {
    errors.push('LOCAL_DB_PASSWORD is required in .env file');
  }

  // Check target database password
  if (!config.target.password) {
    errors.push('SUPABASE_DB_PASSWORD is required in .env file');
  }

  if (errors.length > 0) {
    console.error('Configuration errors:');
    errors.forEach(err => console.error(`  - ${err}`));
    process.exit(1);
  }
}

// Run validation
validateConfig();

module.exports = config;
