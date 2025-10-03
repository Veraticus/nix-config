// Common filter rules shared between accounts
// These patterns work for both personal and work email

local lib = import 'gmailctl.libsonnet';

// Helper functions
local contains(s) = { contains: s };
local hasTheWord(s) = { hasTheWord: s };

{
  // Common label definitions that both accounts can use
  labels: {
    // Priority/Organization
    needs_response: { name: 'Needs Response' },
    waiting_reply: { name: 'Waiting for Reply' },
    priority: { name: 'Priority/VIP' },
    today: { name: 'Today' },
    
    // Content categories
    newsletters: { name: 'Newsletters' },
    marketing: { name: 'Marketing' },
    notifications: { name: 'Notifications' },
    transactional: { name: 'Transactional' },
    receipts: { name: 'Receipts' },
    
    // Source categories
    github: { name: 'GitHub' },
    monitoring: { name: 'Monitoring' },
    ci_cd: { name: 'CI/CD' },
    automated: { name: 'Automated' },
    
    // Archive categories
    old_archive: { name: 'Old Archive' },
    bulk_archive: { name: 'Bulk Archive' },
  },

  // Common rules that apply to most email accounts
  rules: {
    // Archive old unread emails
    archiveOldUnread: {
      filter: {
        and: [
          { query: 'is:unread' },
          { query: 'older_than:6m' },
          { not: { query: 'is:starred' } },
          { not: { query: 'is:important' } },
        ],
      },
      actions: {
        labels: ['Old Archive'],
      },
    },

    // GitHub notifications
    github: {
      filter: {
        or: [
          { from: 'notifications@github.com' },
          { from: 'noreply@github.com' },
          { list: 'github.com' },
        ],
      },
      actions: {
        labels: ['GitHub', 'Notifications'],
      },
    },

    // Newsletter detection
    newsletters: {
      filter: {
        or: [
          { list: '*' },  // Has list headers
          contains('unsubscribe'),
          contains('newsletter'),
          contains('weekly digest'),
          contains('daily digest'),
          { from: '*newsletter*' },
        ],
      },
      actions: {
        labels: ['Newsletters'],
        markImportant: false,
      },
    },

    // Marketing emails
    marketing: {
      filter: {
        or: [
          contains('marketing'),
          contains('promotion'),
          contains('special offer'),
          contains('sale'),
          contains('discount'),
          contains('deal'),
          { subject: '*% off*' },
          { subject: '*$ off*' },
        ],
      },
      actions: {
        labels: ['Marketing'],
        markImportant: false,
      },
    },

    // Transactional emails
    transactional: {
      filter: {
        or: [
          contains('receipt'),
          contains('invoice'),
          contains('order confirmation'),
          contains('payment'),
          contains('transaction'),
          contains('purchase'),
          { from: '*@stripe.com' },
          { from: '*@paypal.com' },
          { from: '*@square*.com' },
        ],
      },
      actions: {
        labels: ['Transactional', 'Receipts'],
        markImportant: false,
      },
    },

    // CI/CD notifications
    cicd: {
      filter: {
        or: [
          { from: '*@circleci.com' },
          { from: '*@travis-ci.org' },
          { from: '*@jenkins*' },
          { from: 'builds@*' },
          { from: 'ci@*' },
          { from: '*gitlab*' },
          contains('build failed'),
          contains('build passed'),
          contains('deployment'),
        ],
      },
      actions: {
        labels: ['CI/CD', 'Automated'],
      },
    },

    // Monitoring alerts
    monitoring: {
      filter: {
        or: [
          { from: '*@pagerduty.com' },
          { from: '*@opsgenie.com' },
          { from: '*monitoring*' },
          { from: '*alerts*' },
          contains('alert'),
          contains('warning'),
          contains('critical'),
          { subject: '[ALERT]*' },
        ],
      },
      actions: {
        labels: ['Monitoring', 'Priority/VIP'],
        markImportant: true,
        star: true,
      },
    },

    // Automated emails
    automated: {
      filter: {
        or: [
          { from: 'donotreply@*' },
          { from: 'do-not-reply@*' },
          { from: 'notifications@*' },
          { from: 'alerts@*' },
          { from: 'system@*' },
          { from: 'automated@*' },
          { from: 'bot@*' },
          { from: '*noreply*' },
          { from: '*no-reply*' },
        ],
      },
      actions: {
        labels: ['Automated'],
        markImportant: false,
      },
    },
  },

  // Helper to create a "real human" filter
  realHumanFilter: {
    and: [
      { not: { list: '*' } },
      { not: { from: '*noreply*' } },
      { not: { from: '*no-reply*' } },
      { not: { from: '*donotreply*' } },
      { not: { from: '*automated*' } },
      { not: { from: '*notifications*' } },
      { not: { from: '*bot@*' } },
    ],
  },
}
