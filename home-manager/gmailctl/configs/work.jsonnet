// Gmail filters for josh@crossnokaye.com (work account)
// Enhanced with all best practices from research + personal config
//
// INBOX SECTIONS (Multiple Inboxes)
// Configure these 5 sections in Gmail Settings > Multiple Inboxes:
//
// Section 1: 🚨 Critical
//   Query: in:inbox AND (label:🚨-critical OR subject:URGENT OR subject:CRITICAL OR subject:DOWN)
//   Outages, incidents, and urgent issues - absolute top priority
//
// Section 2: 👥 Team
//   Query: in:inbox AND (label:👥-team OR label:📨-direct OR label:docs/comments)
//   Your coworkers, direct messages, and doc comments - internal collaboration
//
// Section 3: 🎫 Support & External
//   Query: in:inbox AND (label:🎫-support OR label:👤-external-human)
//   ALL support tickets + external humans - people needing help or responses
//
// Section 4: 📋 Business
//   Query: in:inbox AND (label:💰-finance OR label:⚖️-legal OR label:compliance/drata OR label:📦-shipping)
//   Finance, legal, compliance, and business purchases - administrative tasks
//
// Section 5: ⭐ Starred & Alerts
//   Query: in:inbox AND (is:starred OR (label:monitoring/alerts AND is:unread) OR (label:security/critical AND is:unread))
//   Manual overrides + unread monitoring/security alerts not critical enough for section 1

local lib = import 'gmailctl.libsonnet';
local common = import 'lib/common-rules.libsonnet';

// Internal team members who send real emails
local teamMembers = [
  'kathryn@crossnokaye.com',
  'raphael@crossnokaye.com',
  'dmag@crossnokaye.com',
  'neenu@crossnokaye.com',
  'perry@crossnokaye.com',
  'frank@crossnokaye.com',
  'annie@crossnokaye.com',
  'katie@crossnokaye.com',
  'merc@crossnokaye.com',
  'mitch@crossnokaye.com',
  'taryn@crossnokaye.com',
  'jborneman@crossnokaye.com',
];

// Monitoring/DevOps services
local monitoringServices = [
  '*@honeycomb.io',
  '*@intruder.io',
  '*@pagerduty.com',
  '*@account.pagerduty.com',
  '*@md.getsentry.com',
  '*@alerts.mongodb.com',
  '*@grafana.com',
  '*@cypress.io',
  '*@rapid7.com',
];

// GitHub notifications (less common but using proven pattern)
local githubNotifications = [
  { type: 'assign', label: 'assigned' },
  { type: 'mention', label: 'mentioned', important: true },
  { type: 'review_requested', label: 'review-requested', important: true },
  { type: 'security_alert', label: 'security-alert', important: true },
  { type: 'comment', label: 'commented' },
  { type: 'push', label: 'pushed' },
  { type: 'state_change', label: 'state-changed' },
];

// Generate GitHub rules
local githubRules = std.flattenArrays([
  [
    {
      filter: {
        and: [
          { from: 'notifications@github.com' },
          { cc: notification.type + '@noreply.github.com' },
        ],
      },
      actions: {
        labels: ['github/' + notification.label],
        markImportant: if std.objectHas(notification, 'important') && notification.important then true else null,
      },
    }
  ]
  for notification in githubNotifications
]);

local rules = 
  // GitHub rules first (proven pattern)
  githubRules +
  [
    // NUCLEAR: Archive ALL automated devops emails immediately
    // This is 17.4% of your inbox!
    {
      filter: {
        from: 'devops@crossnokaye.com',
      },
      actions: {
        labels: ['devops/robot'],
        markImportant: false,
      },
    },

    // AGGRESSIVE: Archive old unread (91.4% unread!)
    {
      filter: {
        and: [
          { query: 'is:unread' },
          { query: 'older_than:1w' },  // Even more aggressive - 1 week
          { not: { query: 'is:starred' } },
          { not: { query: 'is:important' } },
        ],
      },
      actions: {
        labels: ['auto-archived/old-unread'],
      },
    },

    // CRITICAL: Outages and incidents (BEFORE other filters)
    {
      filter: {
        and: [
          { or: [
            { query: '"[URGENT]"' },
            { query: '"[EMERGENCY]"' },
            { query: '"[CRITICAL]"' },
            { query: '"[OUTAGE]"' },
            { query: '"[INCIDENT]"' },
            { query: '"service down"' },
            { query: '"system down"' },
            { query: '"site down"' },
            { query: '"production outage"' },
            { query: '"pager alert"' },
            { query: '"on-call alert"' },
          ]},
          { not: { query: 'unsubscribe' } },  // Exclude marketing emails
        ],
      },
      actions: {
        star: true,
        markImportant: true,
        labels: ['🚨-critical'],  // Emoji makes it stand out
        // NO archive - must stay visible
      },
    },

    // Real team members - ALWAYS visible
    // Anyone from crossnokaye.com domain except automated senders
    {
      filter: {
        and: [
          { from: '*@crossnokaye.com' },
          { not: { from: 'devops@crossnokaye.com' } },  // Already handled separately
          { not: { from: '*noreply@crossnokaye.com' } },
          { not: { from: '*no-reply@crossnokaye.com' } },
          { not: { from: '*automated@crossnokaye.com' } },
          { not: { query: 'unsubscribe' } },  // Exclude bulk mail from internal systems
        ],
      },
      actions: {
        labels: ['👥-team'],
        markImportant: true,
        // NO archive
      },
    },

    // Your direct boss/reports (add as needed)
    {
      filter: {
        and: [
          { or: [
            { from: 'dmag@crossnokaye.com' },  // Example - adjust to your manager
            { to: 'josh@crossnokaye.com' },   // Directly to you
          ]},
          { not: { query: 'unsubscribe' } },  // But not bulk mail
        ],
      },
      actions: {
        labels: ['📨-direct'],
        star: true,
        markImportant: true,
      },
    },

    // Monitoring - Split critical vs noise
    {
      filter: {
        and: [
          { or: [{ from: service } for service in monitoringServices] },
          { or: [
            { query: '"monitoring alert"' },
            { query: '"[ALERT]"' },
            { query: '"test failed"' },
            { query: '"build failed"' },
            { query: '"deployment failed"' },
            { query: '"error rate"' },
            { query: '"critical alert"' },
            { query: '"severity: critical"' },
          ]},
        ],
      },
      actions: {
        labels: ['monitoring/alerts'],
        star: true,
        markImportant: true,
      },
    },

    // Non-critical monitoring → ARCHIVE
    {
      filter: {
        or: [{ from: service } for service in monitoringServices],
      },
      actions: {
        labels: ['monitoring/noise'],
      },
    },

    // Support tickets - expanded beyond just Honeycomb
    {
      filter: {
        or: [
          // Honeycomb tickets
          { and: [
            { from: 'support@honeycomb.io' },
            { subject: '*ticket*' },
          ]},
          // General support patterns
          { from: '*@support.*' },
          { from: '*@help.*' },
          { from: '*@ticket.*' },
          { from: '*@zendesk.com' },
          { from: '*@helpdesk.*' },
          { from: '*@freshdesk.com' },
          { from: '*@intercom.io' },
          { subject: '*ticket #*' },
          { subject: '*case #*' },
          { subject: '*support request*' },
          { query: '"your ticket"' },
          { query: '"support ticket"' },
          { query: '"case number"' },
        ],
      },
      actions: {
        labels: ['🎫-support'],
        star: true,
        markImportant: true,
      },
    },

    // Other Honeycomb → archive
    {
      filter: {
        from: '*@honeycomb.io',
      },
      actions: {
        labels: ['tools/honeycomb'],
      },
    },

    // Cleary (7.4%) → ARCHIVE
    {
      filter: {
        from: '*@gocleary.com',
      },
      actions: {
        labels: ['tools/cleary'],
      },
    },

    // Intruder security (4.8%) - could be important
    {
      filter: {
        and: [
          { from: '*@intruder.io' },
          { or: [
            { subject: '*vulnerability*' },
            { subject: '*security*' },
            { subject: '*critical*' },
          ]},
        ],
      },
      actions: {
        labels: ['security/critical'],
        star: true,
        markImportant: true,
      },
    },

    // Other Intruder → archive
    {
      filter: {
        from: '*@intruder.io',
      },
      actions: {
        labels: ['security/scans'],
      },
    },

    // Drata compliance - keep visible but organized
    {
      filter: {
        or: [
          { from: '*@drata.com' },
          { from: '*@drata.intercom-mail.com' },
        ],
      },
      actions: {
        labels: ['compliance/drata'],
        // NO archive - compliance is important
      },
    },

    // Jira/Atlassian → mostly noise
    {
      filter: {
        or: [
          { from: '*@crossnokaye.atlassian.net' },
          { from: '*@e.atlassian.com' },
        ],
      },
      actions: {
        labels: ['tools/jira'],
      },
    },

    // Google Docs comments - someone needs your input
    {
      filter: {
        from: 'comments-noreply@docs.google.com',
      },
      actions: {
        labels: ['docs/comments'],
        star: true,
        markImportant: true,
      },
    },

    // Calendar events (from personal best practices)
    {
      filter: {
        or: [
          { from: 'calendar-notification@google.com' },
          { has: 'filename:invite.ics' },
        ],
      },
      actions: {
        labels: ['📅-calendar'],
        star: true,
      },
    },

    // Auto-archive accepted calendar invites
    {
      filter: {
        and: [
          { has: 'filename:invite.ics' },
          { query: 'accepted OR "Yes, I\'ll attend"' },
        ],
      },
      actions: {
        labels: ['calendar/accepted'],
      },
    },

    // Contracts and legal
    {
      filter: {
        or: [
          { from: '*@docusign.net' },
          { query: '"please sign"' },
          { query: '"signature required"' },
          { query: '"sign contract"' },
          { query: '"sign agreement"' },
          { query: '"execute agreement"' },
          { query: '"NDA attached"' },
          { query: '"non-disclosure agreement"' },
        ],
      },
      actions: {
        labels: ['⚖️-legal'],
        star: true,
        markImportant: true,
      },
    },

    // Financial/expenses
    {
      filter: {
        and: [
          { or: [
            // Expense management systems
            { from: '*@expensify.com' },
            { from: '*@concur.com' },
            { from: '*@certify.com' },
            { from: '*@divvy.com' },
            { from: '*@ramp.com' },
            { from: '*@brex.com' },
            // Invoice/billing addresses
            { from: '*invoice*' },
            { from: '*billing*' },
            { from: '*receipts*' },
            { from: '*statements*' },
            { from: '*@bill.com' },
            { from: '*@quickbooks.com' },
            // Accounting/finance
            { from: '*@gusto.com' },
            { from: '*@adp.com' },
            { from: '*accounting*' },
            { from: '*finance*' },
            // DocuSign for contracts/invoices
            { from: '*@docusign.net' },
            // Keep some specific queries for edge cases
            { subject: 'invoice' },
            { subject: 'receipt' },
            { subject: 'payment' },
            { subject: 'expense' },
            { subject: 'reimbursement' },
          ]},
          { not: { query: 'unsubscribe' } },  // Exclude marketing emails
        ],
      },
      actions: {
        labels: ['💰-finance'],
        markImportant: true,
      },
    },

    // Shipping notifications for business purchases
    {
      filter: {
        or: [
          { from: '*@shipment.*' },
          { from: '*@delivery.*' },
          { query: '"has shipped"' },
          { query: '"order shipped"' },
          { query: '"package shipped"' },
          { query: '"tracking information"' },
          { query: '"delivery scheduled"' },
          { query: '"order dispatched"' },
          { query: '"tracking number"' },
          { query: '"track your package"' },
          { query: '"track your order"' },
        ],
      },
      actions: {
        labels: ['📦-shipping'],
        star: true,
        markImportant: true,
      },
    },

    // AWS via email (not devops@)
    {
      filter: {
        or: [
          { from: 'aws-root@crossnokaye.com' },
          { from: '*@amazon.com' },
          { from: '*@aws.amazon.com' },
        ],
      },
      actions: {
        labels: ['aws'],
      },
    },

    // All remaining SaaS tools → ARCHIVE
    {
      filter: {
        or: [
          { from: '*@slack.com' },
          { from: '*@email.slackhq.com' },
          { from: '*@datawire.io' },
          { from: '*@tailscale.com' },
          { from: '*@okta.com' },
          { from: '*@1password.com' },
          { from: '*@greenhouse.io' },
          { from: '*@cypress.io' },
        ],
      },
      actions: {
        labels: ['tools/misc'],
      },
    },

    // Recruiting spam
    {
      filter: {
        or: [
          { from: '*@powertofly.com' },
          { from: '*recruiter*' },
          { from: '*recruiting*' },
          { query: '"job opportunity"' },
          { query: '"open position"' },
          { query: '"career opportunity"' },
          { query: '"role at"' },
        ],
      },
      actions: {
        labels: ['recruiting'],
      },
    },

    // Marketing/Events/Newsletters (51.2% have list headers!)
    {
      filter: {
        and: [
          { or: [
            { list: '*' },
            { query: 'unsubscribe' },
            { from: '*@campaigns.*' },
            { from: '*@mail.*' },
            { from: '*@email.*' },
            { from: '*@engage.*' },
            { from: '*@reply.*' },
            { from: '*newsletter*' },
          ]},
          // Don't archive emails already categorized
          { not: { query: 'label:🚨-critical' } },
          { not: { query: 'label:📨-direct' } },
          { not: { query: 'label:👥-team' } },
          { not: { query: 'label:👤-external-human' } },
          { not: { query: 'label:💰-finance' } },
          { not: { query: 'label:⚖️-legal' } },
          { not: { query: 'label:📦-shipping' } },
          { not: { query: 'label:🎫-support' } },
          { not: { query: 'label:docs/comments' } },
          { not: { query: 'label:compliance/drata' } },
          { not: { query: 'label:📅-calendar' } },
          { not: { query: 'label:monitoring/alerts' } },
          { not: { query: 'label:security/critical' } },
        ],
      },
      actions: {
        labels: ['bulk'],
      },
    },

    // Auto-archive all remaining noreply
    {
      filter: {
        and: [
          { or: [
            { from: '*noreply*' },
            { from: '*no-reply*' },
            { from: '*donotreply*' },
            { from: '*notifications*' },
            { from: '*automated*' },
          ]},
          // Don't archive emails already categorized
          { not: { query: 'label:🚨-critical' } },
          { not: { query: 'label:📨-direct' } },
          { not: { query: 'label:👥-team' } },
          { not: { query: 'label:👤-external-human' } },
          { not: { query: 'label:💰-finance' } },
          { not: { query: 'label:⚖️-legal' } },
          { not: { query: 'label:📦-shipping' } },
          { not: { query: 'label:🎫-support' } },
          { not: { query: 'label:docs/comments' } },
          { not: { query: 'label:compliance/drata' } },
          { not: { query: 'label:📅-calendar' } },
          { not: { query: 'label:monitoring/alerts' } },
          { not: { query: 'label:security/critical' } },
        ],
      },
      actions: {
        labels: ['automated'],
      },
    },

    // External humans (what's left)
    {
      filter: {
        and: [
          { not: { from: '*@crossnokaye.com' } },
          { not: { list: '*' } },
          { not: { from: '*noreply*' } },
          { not: { from: '*no-reply*' } },
          { not: { from: '*donotreply*' } },
          { not: { from: '*notifications*' } },
          { not: { from: '*notification*' } },
          { not: { from: '*shipping*' } },
          { not: { from: '*tracking*' } },
          { not: { from: '*alert*' } },
          { not: { from: '*system*' } },
          { not: { from: '*automated*' } },
          { not: { from: 'auto-*' } },          // Auto-confirm, auto-reply, etc.
          { not: { from: '*bot@*' } },
          { not: { from: '*@orders.*' } },
          { not: { from: '*@support.*' } },
          { not: { from: '*invoice*' } },       // Invoice/billing systems
          { not: { from: '*billing*' } },       // Billing systems
          { not: { from: '*receipts*' } },      // Receipt systems
          { not: { from: '*statements*' } },    // Statement systems
          { not: { query: 'unsubscribe' } },
        ],
      },
      actions: {
        labels: ['👤-external-human'],
        markImportant: true,
      },
    },
  ];

{
  version: 'v1alpha3',
  author: {
    name: 'Josh Symonds',
    email: 'josh@crossnokaye.com',
  },
  rules: rules,
  labels: [
    // Critical stuff first - emoji for primary action labels
    { name: '🚨-critical' },
    { name: '📨-direct' },
    { name: '👥-team' },
    { name: '👤-external-human' },
    
    // Hierarchical labels - no emoji on sub-labels or categories
    { name: 'auto-archived' },
    { name: 'auto-archived/old-unread' },
    { name: 'automated' },
    { name: 'aws' },
    { name: 'bulk' },
    { name: '📅-calendar' },  // Primary visual category
    { name: 'calendar/accepted' },
    { name: 'compliance' },
    { name: 'compliance/drata' },
    { name: 'devops' },
    { name: 'devops/robot' },
    { name: 'docs' },
    { name: 'docs/comments' },
    { name: '💰-finance' },  // Primary visual category
    { name: 'github' },
  ] + [
    { name: 'github/' + n.label }
    for n in githubNotifications
  ] + [
    { name: '⚖️-legal' },  // Primary visual category
    { name: 'monitoring' },
    { name: 'monitoring/alerts' },
    { name: 'monitoring/noise' },
    { name: 'recruiting' },
    { name: 'security' },
    { name: 'security/critical' },
    { name: 'security/scans' },
    { name: '📦-shipping' },
    { name: '🎫-support' },
    { name: 'support/honeycomb' },
    { name: 'tools' },
    { name: 'tools/cleary' },
    { name: 'tools/honeycomb' },
    { name: 'tools/jira' },
    { name: 'tools/misc' },
  ],
}
