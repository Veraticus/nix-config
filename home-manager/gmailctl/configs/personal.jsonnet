// Gmail filters for josh@joshsymonds.com
//
// INBOX SECTIONS (Multiple Inboxes)
// Configure these 5 sections in Gmail Settings > Multiple Inboxes:
//
// Section 1: 👤 Humans
//   Query: in:inbox AND (label:👤-humans)
//   Real people who need responses - highest priority
//
// Section 2: 🚨 Critical Life Matters
//   Query: in:inbox AND (label:💰-money OR label:🏥-health OR label:🏛️-government)
//   Financial, health, and government matters - critical and time-sensitive
//
// Section 3: 🎫 Support & Orders
//   Query: in:inbox AND (label:🎫-support OR label:📦-orders)
//   Active support tickets and package tracking - need monitoring/action
//
// Section 4: ⭐ Starred
//   Query: in:inbox AND is:starred
//   Manual priority override - anything you've marked important
//
// Section 5: 🔔 Unread Priority
//   Query: in:inbox AND is:unread AND (label:⭐-priority OR label:github/mentioned OR label:✈️-travel)
//   Safety net for unread: priority emails, GitHub mentions, and travel confirmations

local lib = import 'gmailctl.libsonnet';
local common = import 'lib/common-rules.libsonnet';

// Your actual high-volume retail senders (from analysis)
local retailSenders = [
  '*@email.bananarepublic.com',
  '*@email.lovesac.com', 
  '*@mail.crutchfield.com',
  '*@coyuchi.com',
  '*@em.calvinklein.com',
  '*@handupgloves.com',
  '*@paninos.ccsend.com',
  // Additional retail from analysis
  '*@mail.zillow.com',
  '*@joycoast.com',
  // Wine/vineyard retailers
  '*@foxenvineyard.com',
];

// GitHub notification types (most proven gmailctl pattern)
local githubNotifications = [
  { type: 'assign', label: 'assigned' },
  { type: 'author', label: 'author' },
  { type: 'comment', label: 'commented' },
  { type: 'mention', label: 'mentioned', important: true },
  { type: 'push', label: 'pushed' },
  { type: 'review_requested', label: 'review-requested', important: true },
  { type: 'security_alert', label: 'security-alert', important: true },
  { type: 'state_change', label: 'state-changed' },
  { type: 'subscribed', label: 'watching' },
  { type: 'team_mention', label: 'team-mentioned', important: true },
];

// Generate GitHub rules (proven pattern from research)
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
  // GitHub rules first (they're specific and your #1 sender at 10.8%)
  githubRules +
  [
    // PRIORITY 1: Aggressive unread cleanup (you have 435/500 unread!)
    {
      filter: {
        and: [
          { query: 'is:unread' },
          { query: 'older_than:1m' },  // Even more aggressive given your situation
          { not: { query: 'is:starred' } },
          { not: { query: 'is:important' } },
          // Never archive financial - removed label check due to gmailctl limitation
        ],
      },
      actions: {
        labels: ['auto-archived/old-unread'],
      },
    },

    // CRITICAL: Protect emails from yourself (for notes/reminders)
    {
      filter: {
        from: 'josh@joshsymonds.com',  // Only emails to yourself
      },
      actions: {
        star: true,
        markImportant: true,
        labels: ['⭐-priority'],
      },
    },

    // Financial - NEVER auto-archive (from your analysis + best practices)
    {
      filter: {
        or: [
          { from: '*@chase.com' },
          { from: '*@venmo.com' },
          { from: '*@email.venmo.com' },
          { from: '*@mint.com' },
          { from: '*@wellsfargo.com' },
          { from: '*@bankofamerica.com' },
          { from: '*@americanexpress.com' },
          { from: '*@capitalone.com' },
          { from: '*@schwab.com' },
          { from: '*@fidelity.com' },
          { from: '*@vanguard.com' },
          { from: '*invoice*' },
          { from: '*billing*' },
          { from: '*receipts*' },
          { from: '*statements*' },
          { query: '"bank statement"' },
          { query: '"payment due"' },
          { query: '"invoice number"' },
          { query: '"account statement"' },
          { subject: 'receipt' },
          { subject: 'invoice' },
          { subject: 'payment' },
          { subject: 'bill' },
        ],
      },
      actions: {
        labels: ['💰-money'],
        markImportant: true,
        // NO archive - keep in inbox
      },
    },

    // Calendar events - keep visible (best practice)
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

    // Marketing emails misusing shipping/order addresses
    // Catches common marketing platform signatures in email content
    {
      filter: {
        and: [
          { or: [
            { from: '*shipping*' },
            { from: '*order*' },
            { from: '*fulfillment*' },
          ]},
          { or: [
            // Common marketing platform footprints
            { query: 'constantcontact.com' },
            { query: 'mailchimp.com' },
            { query: 'sendgrid.net' },
            { query: 'klaviyo.com' },
            { query: 'brevo.com' },
            { query: 'sendinblue.com' },
            { query: 'convertkit.com' },
            { query: 'activecampaign.com' },
            { query: 'aweber.com' },
            { query: 'getresponse.com' },
            { query: 'campaign-archive.com' },
            { query: 'list-manage.com' },
            { query: 'mcsv.net' },  // Mailchimp server
            { query: 'rsgsv.net' },  // Common ESP
            { query: 'exacttarget.com' },
            { query: 'salesforce-email.com' },
            { query: 'hubspot.com' },
            { query: 'marketo.com' },
            { query: 'pardot.com' },
            { query: 'eloqua.com' },
            { query: 'ccsend.com' },  // Constant Contact
            // Marketing language that wouldn't appear in real shipping emails
            { query: '"view in browser"' },
            { query: '"add us to your address book"' },
            { query: '"forward to a friend"' },
            { query: '"manage preferences"' },
            { query: '"email preferences"' },
            { query: '"why am I receiving this"' },
          ]},
        ],
      },
      actions: {
        labels: ['🛍️-shopping'],
        markImportant: false,
      },
    },

    // Retail emails (30% of your inbox!)
    {
      filter: {
        or: [{ from: sender } for sender in retailSenders],
      },
      actions: {
        labels: ['🛍️-shopping'],
      },
    },

    // Social/Events (from your analysis)
    {
      filter: {
        or: [
          { from: '*@mailva.evite.com' },  // 2.4% of your inbox
          { from: '*@linkedin.com' },       // 2.8% of your inbox
          { from: '*@todoist.com' },
          { from: '*@facebookmail.com' },
          { from: '*@twitter.com' },
        ],
      },
      actions: {
        labels: ['💬-social'],
      },
    },

    // Kickstarter/BackerKit (from your analysis)
    {
      filter: {
        or: [
          { from: '*@kickstarter.com' },
          { from: '*@backerkit.com' },
        ],
      },
      actions: {
        labels: ['crowdfunding'],
      },
    },

    // Travel - star for easy access
    {
      filter: {
        or: [
          { from: '*@airbnb.com' },
          { from: '*@booking.com' },
          { from: '*@expedia.com' },
          { from: '*@lyft.com' },
          { from: '*@uber.com' },
          { query: '"flight confirmation"' },
          { query: '"boarding pass"' },
          { query: '"travel itinerary"' },
          { query: '"booking confirmation"' },
        ],
      },
      actions: {
        labels: ['✈️-travel'],
        star: true,
        markImportant: true,
      },
    },

    // Health-related emails
    {
      filter: {
        and: [
          { or: [
            { from: '*@myhealth*' },
            { from: '*@healthcare*' },
            { from: '*clinic*' },
            { from: '*hospital*' },
            { from: '*doctor*' },
            { from: '*dental*' },
            { from: '*medical*' },
            { query: 'prescription' },
          ]},
          { not: { from: '*alumni*' } },        // Exclude alumni benefits emails
          { not: { query: 'unsubscribe' } },    // Exclude marketing
        ],
      },
      actions: {
        labels: ['🏥-health'],
        markImportant: true,
        star: true,
      },
    },

    // Government and legal notices - CRITICAL
    {
      filter: {
        or: [
          { from: '*.gov' },
          { from: '*.gov.uk' },
          { from: '*.govt.nz' },
          { from: '*@irs.gov' },
          { from: '*@dmv.*' },
          { from: '*@courts.*' },
          { query: '"driver license"' },
          { query: '"license renewal"' },
          { query: '"tax return"' },
          { query: '"tax payment"' },
          { query: '"jury duty"' },
          { query: '"jury summons"' },
          { query: '"legal summons"' },
          { query: '"citation"' },
          { query: '"vehicle registration"' },
          { and: [
            { query: '"action required"' },
            { or: [
              { from: '*.gov' },
              { query: 'tax' },
              { query: 'jury' },
              { query: 'license' },
              { query: 'registration' },
            ]},
          ]},
          { query: '"legal notice"' },
          { query: '"government notice"' },
        ],
      },
      actions: {
        labels: ['🏛️-government'],
        star: true,
        markImportant: true,
      },
    },

    // Orders and shipping notifications (unified)
    {
      filter: {
        and: [
          { or: [
            // Amazon orders (excluding AWS marketing)
            { and: [
              { from: '*@amazon.com' },
              { not: { from: 'aws-marketing-email-replies@amazon.com' } },
            ]},
            // Shipping and tracking patterns
            { from: '*shipping*' },
            { from: '*tracking*' },
            { from: '*@orders.*' },
            { from: '*@shipment.*' },
            { from: '*@delivery.*' },
            { subject: '*order*' },
            { subject: '*shipped*' },
            { subject: '*tracking*' },
            { subject: '*delivery*' },
            { subject: '*dispatched*' },
            { query: '"tracking number"' },
            { query: '"track your package"' },
            { query: '"track your order"' },
            { query: '"order confirmation"' },
            { query: '"order has been placed"' },
          ]},
          // Exclude promotional emails
          { not: { subject: '*sale*' } },
          { not: { subject: '*promotion*' } },
          { not: { subject: '*discount*' } },
          { not: { subject: '*special offer*' } },
          { not: { subject: '*limited time*' } },
          { not: { query: '"flash sale"' } },
          { not: { query: '"summer sale"' } },
          { not: { query: '"winter sale"' } },
          { not: { query: '"black friday"' } },
          { not: { query: '"cyber monday"' } },
        ],
      },
      actions: {
        labels: ['📦-orders'],
        star: true,
        markImportant: true,
      },
    },

    // Support tickets and customer service
    {
      filter: {
        or: [
          { from: '*@support.*' },
          { from: '*@help.*' },
          { from: '*@ticket.*' },
          { from: '*@zendesk.com' },
          { from: '*@helpdesk.*' },
          { from: '*@freshdesk.com' },
          { from: '*@intercom.io' },
          { subject: '*ticket*' },
          { subject: '*case #*' },
          { subject: '*support request*' },
          { query: '"your ticket"' },
          { query: '"support ticket"' },
          { query: '"case number"' },
        ],
      },
      actions: {
        labels: ['🎫-support'],
        markImportant: true,
      },
    },

    // Auto-archive accepted calendar invites (clever pattern from research)
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

    // Plus addressing - emails to josh+newsletter@joshsymonds.com etc
    {
      filter: { to: 'josh+*@joshsymonds.com' },
      actions: {
        labels: ['plus-addressed'],
      },
    },

    // AWS Marketing emails
    {
      filter: {
        from: 'aws-marketing-email-replies@amazon.com',
      },
      actions: {
        labels: ['marketing-platform'],
        markImportant: false,
      },
    },

    // AWS Service notifications (EOL, deprecations, etc.)
    {
      filter: {
        or: [
          { from: 'no-reply-aws@amazon.com' },
          { and: [
            { from: '*@amazon.com' },
            { or: [
              { subject: '*[AWS Account:*' },
              { subject: '*End of Life*' },
              { subject: '*EOL*' },
              { subject: '*deprecation*' },
              { subject: '*Lex V1*' },
            ]},
          ]},
        ],
      },
      actions: {
        labels: ['aws-notifications'],
        markImportant: true,
      },
    },

    // Enhanced marketing platform detection (before bulk catch-all)
    {
      filter: {
        or: [
          // Marketing platform signatures in email content
          { query: 'constantcontact.com' },
          { query: 'mailchimp.com' },
          { query: 'sendgrid.net' },
          { query: 'klaviyo.com' },
          { query: 'brevo.com' },
          { query: 'sendinblue.com' },
          { query: 'convertkit.com' },
          { query: 'activecampaign.com' },
          { query: 'aweber.com' },
          { query: 'getresponse.com' },
          { query: 'campaign-archive.com' },
          { query: 'list-manage.com' },
          { query: 'mcsv.net' },  // Mailchimp server
          { query: 'rsgsv.net' },  // Common ESP
          { query: 'exacttarget.com' },
          { query: 'salesforce-email.com' },
          { query: 'hubspot.com' },
          { query: 'marketo.com' },
          { query: 'pardot.com' },
          { query: 'eloqua.com' },
          { query: 'ccsend.com' },  // Constant Contact
          { query: 'mailjet.com' },
          { query: 'sendpulse.com' },
          { query: 'mailerlite.com' },
          { query: 'moosend.com' },
          { query: 'omnisend.com' },
          { query: 'drip.com' },
          { query: 'autopilot.com' },
          { query: 'customer.io' },
          { query: 'intercom.io' },
          { query: 'mixmax.com' },
          // Marketing-specific language patterns
          { query: '"view in browser"' },
          { query: '"add us to your address book"' },
          { query: '"forward to a friend"' },
          { query: '"manage preferences"' },
          { query: '"email preferences"' },
          { query: '"why am I receiving this"' },
          { query: '"this email was sent to"' },
          { query: '"you are receiving this because you"' },
          { query: '"update your preferences"' },
          { query: '"manage your subscription"' },
          { query: '"click here to unsubscribe"' },
          { query: '"unsubscribe from this list"' },
          { query: '"update subscription preferences"' },
          { query: '"view this email in your browser"' },
          { query: '"trouble viewing this email"' },
          { query: '"ensure delivery to your inbox"' },
          { query: '"whitelist our email"' },
          { query: '"mark as not spam"' },
          { query: '"move to inbox"' },
        ],
      },
      actions: {
        labels: ['marketing-platform'],
        markImportant: false,
      },
    },

    // Bulk mail catch-all (68% of your emails have list headers!)
    {
      filter: {
        and: [
          { or: [
            { list: '*' },
            { query: 'unsubscribe' },
          ]},
          // Don't archive emails already categorized as important
          { not: { query: 'label:👤-humans' } },
          { not: { query: 'label:💰-money' } },
          { not: { query: 'label:🏥-health' } },
          { not: { query: 'label:🏛️-government' } },
          { not: { query: 'label:📦-orders' } },
          { not: { query: 'label:🎫-support' } },
          { not: { query: 'label:✈️-travel' } },
          { not: { query: 'label:⭐-priority' } },
        ],
      },
      actions: {
        labels: ['bulk'],
      },
    },

    // Automated senders
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
          // Don't archive emails already categorized as important
          { not: { query: 'label:👤-humans' } },
          { not: { query: 'label:💰-money' } },
          { not: { query: 'label:🏥-health' } },
          { not: { query: 'label:🏛️-government' } },
          { not: { query: 'label:📦-orders' } },
          { not: { query: 'label:🎫-support' } },
          { not: { query: 'label:✈️-travel' } },
          { not: { query: 'label:⭐-priority' } },
        ],
      },
      actions: {
        labels: ['automated'],
      },
    },

    // SMS messages (before humans filter to prevent misclassification)
    {
      filter: {
        or: [
          { from: '*@msg.fi.google.com' },      // Google Voice
          { from: '*@txt.voice.google.com' },   // Google Voice alternative
          { from: '1800*' },  // Toll-free SMS prefixes
          { from: '1833*' },  // Catches (833) numbers
          { from: '1844*' },
          { from: '1855*' },
          { from: '1866*' },
          { from: '1877*' },
          { from: '1888*' },
        ],
      },
      actions: {
        labels: ['📱-sms'],
        markImportant: false,
      },
    },

    // Real humans filter (what's left after all other filters)
    {
      filter: {
        and: [
          { not: { list: '*' } },
          { not: { from: '*noreply*' } },
          { not: { from: '*no-reply*' } },
          { not: { from: '*donotreply*' } },
          { not: { from: '*notifications*' } },
          { not: { from: '*notification*' } },  // Singular form
          { not: { from: '*shipping*' } },      // Shipping notifications
          { not: { from: '*tracking*' } },      // Tracking updates
          { not: { from: '*alert*' } },         // Automated alerts
          { not: { from: '*system*' } },        // System messages
          { not: { from: '*automated*' } },     // Explicitly automated
          { not: { from: 'auto-*' } },          // Auto-confirm, auto-reply, etc.
          { not: { from: '*bot@*' } },          // Bot accounts
          { not: { from: '*@orders.*' } },      // Order systems (like Apple)
          { not: { from: '*@support.*' } },     // Support ticketing systems
          { not: { from: '*invoice*' } },       // Invoice/billing systems
          { not: { from: '*billing*' } },       // Billing systems
          { not: { from: '*receipts*' } },      // Receipt systems
          { not: { from: '*statements*' } },    // Statement systems
          { not: { from: '*alumni*' } },        // Alumni associations
          { not: { from: '*@meyerandassoc.com' } }, // Marketing agencies
          { not: { query: 'unsubscribe' } },
          { not: { query: 'click here to unsubscribe' } },
          { not: { query: 'do not wish to receive' } },
        ],
      },
      actions: {
        labels: ['👤-humans'],
        markImportant: true,
      },
    },
  ];

{
  version: 'v1alpha3',
  author: {
    name: 'Josh Symonds',
    email: 'josh@joshsymonds.com',
  },
  rules: rules,
  labels: [
    // Hierarchical labels (best practice)
    { name: 'auto-archived' },
    { name: 'auto-archived/old-unread' },
    { name: 'automated' },
    { name: 'aws-notifications' },
    { name: 'bulk' },
    { name: '📅-calendar' },
    { name: 'calendar/accepted' },
    { name: 'crowdfunding' },
    { name: 'github' },
  ] + [
    { name: 'github/' + n.label }
    for n in githubNotifications
  ] + [
    { name: '🏛️-government' },
    { name: '🏥-health' },
    { name: '👤-humans' },
    { name: 'marketing-platform' },
    { name: '💰-money' },
    { name: '📦-orders' },
    { name: 'plus-addressed' },
    { name: '⭐-priority' },
    { name: '🛍️-shopping' },
    { name: '📱-sms' },
    { name: '💬-social' },
    { name: '🎫-support' },
    { name: '✈️-travel' },
  ],
}
