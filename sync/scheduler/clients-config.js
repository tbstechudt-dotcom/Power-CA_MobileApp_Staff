/**
 * Multi-Client Configuration for Automated Sync
 *
 * Configure all 6 clients here with their org_id and sync schedules.
 * Each client can have different sync times to avoid server overload.
 */

module.exports = {
  // Client configurations
  clients: [
    {
      id: 1,
      name: 'Client 1',
      org_id: 1,
      enabled: true,
      schedule: {
        // Daily incremental sync at 2:00 AM
        incremental: '0 2 * * *',
        // Weekly full sync on Sunday at 3:00 AM
        full: '0 3 * * 0'
      }
    },
    {
      id: 2,
      name: 'Client 2',
      org_id: 2,
      enabled: true,
      schedule: {
        // Daily incremental sync at 2:15 AM (staggered)
        incremental: '15 2 * * *',
        // Weekly full sync on Sunday at 3:30 AM
        full: '30 3 * * 0'
      }
    },
    {
      id: 3,
      name: 'Client 3',
      org_id: 3,
      enabled: true,
      schedule: {
        // Daily incremental sync at 2:30 AM (staggered)
        incremental: '30 2 * * *',
        // Weekly full sync on Sunday at 4:00 AM
        full: '0 4 * * 0'
      }
    },
    {
      id: 4,
      name: 'Client 4',
      org_id: 4,
      enabled: true,
      schedule: {
        // Daily incremental sync at 2:45 AM (staggered)
        incremental: '45 2 * * *',
        // Weekly full sync on Sunday at 4:30 AM
        full: '30 4 * * 0'
      }
    },
    {
      id: 5,
      name: 'Client 5',
      org_id: 5,
      enabled: true,
      schedule: {
        // Daily incremental sync at 3:00 AM (staggered)
        incremental: '0 3 * * *',
        // Weekly full sync on Sunday at 5:00 AM
        full: '0 5 * * 0'
      }
    },
    {
      id: 6,
      name: 'Client 6',
      org_id: 6,
      enabled: true,
      schedule: {
        // Daily incremental sync at 3:15 AM (staggered)
        incremental: '15 3 * * *',
        // Weekly full sync on Sunday at 5:30 AM
        full: '30 5 * * 0'
      }
    }
  ],

  // Global sync settings
  settings: {
    // Enable/disable all automatic syncs
    autoSyncEnabled: true,

    // Retry failed syncs
    retryOnFailure: true,
    maxRetries: 3,
    retryDelay: 300000, // 5 minutes

    // Timeout settings
    syncTimeout: 600000, // 10 minutes per sync

    // Logging
    logLevel: 'info', // 'error', 'warn', 'info', 'debug'
    logRetentionDays: 30,

    // Notifications
    emailNotifications: {
      enabled: false, // Set to true to enable email alerts
      onFailure: true,
      onSuccess: false,
      recipients: ['admin@example.com']
    }
  },

  // Email configuration (for notifications)
  email: {
    service: 'gmail', // or 'smtp'
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: 'your-email@gmail.com',
      pass: 'your-app-password' // Use app password, not regular password
    },
    from: 'PowerCA Sync <noreply@powerca.com>'
  }
};
