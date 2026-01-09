/**
 * Multi-Client Configuration for Automated Sync
 *
 * Configure all 6 clients here with their org_id and sync schedules.
 * Each client can have different sync times to avoid server overload.
 */

module.exports = {
  // Client configurations
  // IMPORTANT: Set the client's name and org_id before deployment
  clients: [
    {
      id: 1,
      name: 'CLIENT_NAME_HERE',        // <- CHANGE THIS to client's company name
      org_id: 1,                       // <- CHANGE THIS to client's org_id from database
      enabled: true,
      schedule: {
        // Daily incremental sync at 2:00 AM
        incremental: '0 2 * * *',
        // Weekly full sync on Sunday at 3:00 AM
        full: '0 3 * * 0'
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
